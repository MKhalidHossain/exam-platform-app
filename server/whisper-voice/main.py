"""
Self-hosted Whisper transcription service for the EJ7696 voice assistant.

Contract (matches lib/voice/recognition/cloud_speech_service.dart):
  POST  /api/voice/transcribe-command   multipart/form-data
    audio             m4a/wav/ogg file (mono 16 kHz preferred)
    locale            BCP-47 locale tag (e.g. "en-US", "en-GB", "en-NG")
    screenContext     "mcq" | "examReview" | "examLoading" | "examSession" | "quizSettings"
    availableCommands JSON-encoded list of allowed commands
  Returns 200 application/json:
    {
      "transcript": "<best hypothesis>",
      "confidence": 0.0..1.0,
      "provider":   "whisper-server",
      "language":   "<requested locale>",
      "durationMs": <int>
    }
  Returns 401 if AUTH_TOKEN env var is set and the Authorization header
  doesn't match `Bearer <AUTH_TOKEN>`.

faster-whisper is used (CTranslate2 backend — 4x faster than openai-whisper,
CPU-friendly, GPU optional). `initial_prompt` is built from the per-screen
`availableCommands` list, which biases the decoder toward the expected
command vocabulary and recovers most accent-misheard answers.
"""

from __future__ import annotations

import asyncio
import json
import logging
import math
import os
import tempfile
import time
from typing import List

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse
from faster_whisper import WhisperModel

LOG = logging.getLogger("whisper-voice")
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))

MODEL_NAME = os.getenv("WHISPER_MODEL", "small.en")
DEVICE = os.getenv("WHISPER_DEVICE", "cpu")  # "cuda" if you have a GPU
COMPUTE_TYPE = os.getenv("WHISPER_COMPUTE_TYPE", "int8")  # int8 = CPU-friendly
AUTH_TOKEN = os.getenv("AUTH_TOKEN", "").strip()
MAX_AUDIO_SECONDS = int(os.getenv("MAX_AUDIO_SECONDS", "20"))
MODEL_CACHE_DIR = os.getenv("MODEL_CACHE_DIR", "/models")

# Reuse one model across requests; faster-whisper is thread-safe for
# transcribe() once the model has been loaded.
LOG.info("loading whisper model=%s device=%s compute=%s", MODEL_NAME, DEVICE, COMPUTE_TYPE)
MODEL = WhisperModel(
    MODEL_NAME,
    device=DEVICE,
    compute_type=COMPUTE_TYPE,
    download_root=MODEL_CACHE_DIR,
)
LOG.info("whisper model loaded")

app = FastAPI(title="EJ7696 Whisper Voice", version="1.0")


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "model": MODEL_NAME, "device": DEVICE}


@app.post("/api/voice/transcribe-command")
async def transcribe_command(
    request: Request,
    audio: UploadFile = File(...),
    locale: str = Form("en-US"),
    screenContext: str = Form("none"),
    availableCommands: str = Form("[]"),
) -> JSONResponse:
    _check_auth(request)

    try:
        commands: List[str] = json.loads(availableCommands)
        if not isinstance(commands, list):
            commands = []
    except json.JSONDecodeError:
        commands = []

    # Save the upload to a temp file — faster-whisper's transcribe() reads
    # from a path and decodes via ffmpeg internally.
    suffix = _suffix_for(audio.filename or "audio.m4a")
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        chunk_count = 0
        while True:
            chunk = await audio.read(64 * 1024)
            if not chunk:
                break
            tmp.write(chunk)
            chunk_count += 1
        tmp_path = tmp.name

    started = time.perf_counter()
    try:
        transcript, confidence, language = await asyncio.to_thread(
            _transcribe_sync, tmp_path, locale, commands
        )
    except Exception as exc:  # noqa: BLE001
        LOG.exception("transcription failed: %s", exc)
        raise HTTPException(status_code=500, detail="Transcription failed.") from exc
    finally:
        _safe_unlink(tmp_path)

    duration_ms = int((time.perf_counter() - started) * 1000)

    LOG.info(
        "transcribed screen=%s locale=%s commands=%d transcript=%r confidence=%.2f duration_ms=%d",
        screenContext,
        locale,
        len(commands),
        transcript,
        confidence,
        duration_ms,
    )

    return JSONResponse(
        {
            "transcript": transcript,
            "confidence": round(confidence, 4),
            "provider": "whisper-server",
            "language": language or locale,
            "durationMs": duration_ms,
        }
    )


def _transcribe_sync(
    path: str, locale: str, commands: List[str]
) -> tuple[str, float, str]:
    initial_prompt = _build_initial_prompt(commands)
    segments, info = MODEL.transcribe(
        path,
        language=_whisper_language_for(locale),
        beam_size=5,
        best_of=5,
        temperature=0.0,
        condition_on_previous_text=False,
        initial_prompt=initial_prompt,
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 250},
        no_speech_threshold=0.6,
    )

    pieces: list[str] = []
    avg_log_prob = 0.0
    total_words = 0
    for segment in segments:
        text = (segment.text or "").strip()
        if not text:
            continue
        pieces.append(text)
        words = max(len(text.split()), 1)
        avg_log_prob += float(segment.avg_logprob) * words
        total_words += words

    transcript = " ".join(pieces).strip()
    if total_words > 0:
        # avg_logprob is in (-∞, 0]; map to a 0..1 confidence via exp.
        confidence = max(0.0, min(1.0, math.exp(avg_log_prob / total_words)))
    else:
        confidence = 0.0
    return transcript, confidence, info.language or ""


def _build_initial_prompt(commands: List[str]) -> str:
    base = (
        "This is a short voice command from a multiple-choice quiz app. "
        "The user usually says a single letter answer (A, B, C, or D), "
        "a yes/no, or a short navigation command."
    )
    if not commands:
        return base
    # Trim to the most-likely 32 commands so the prompt stays compact.
    sample = commands[:32]
    return base + " Likely commands: " + ", ".join(sample) + "."


def _whisper_language_for(locale: str) -> str:
    # Whisper takes ISO-639-1 language codes. Anything starting with `en` is
    # English; we let the model auto-detect for unknown tags.
    locale = (locale or "").lower()
    if locale.startswith("en"):
        return "en"
    return ""


def _suffix_for(filename: str) -> str:
    lower = filename.lower()
    for ext in (".m4a", ".mp4", ".wav", ".ogg", ".webm", ".mp3", ".flac"):
        if lower.endswith(ext):
            return ext
    return ".m4a"


def _safe_unlink(path: str) -> None:
    try:
        os.unlink(path)
    except OSError:
        pass


def _check_auth(request: Request) -> None:
    if not AUTH_TOKEN:
        return
    header = request.headers.get("authorization", "")
    expected = f"Bearer {AUTH_TOKEN}"
    if header != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")

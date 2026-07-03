# EJ7696 Whisper Voice Server

Self-hosted Whisper transcription service for the EJ7696 voice assistant.

The Flutter app posts a short m4a clip to `/api/voice/transcribe-command` and
this service returns a transcript using
[`faster-whisper`](https://github.com/SYSTRAN/faster-whisper).

## What you get

- `small.en` Whisper model (~466 MB) — handles UK/US/African English far
  more accurately than the on-device Android STT the app uses today.
- `initial_prompt` biasing: each request includes the per-screen
  `availableCommands` list (A/B/C/D, next, back, submit, …) which lifts
  command-recognition accuracy substantially.
- VAD pre-filtering: silence is trimmed before transcription, so a 20 s
  capture with 2 s of speech transcribes in <500 ms on a 2 vCPU VPS.
- Optional bearer-token auth to keep random callers off the endpoint.

## Quick start on the VPS

```bash
cd /opt
git clone <your repo>
cd <your repo>/server/whisper-voice

# Pick a strong random token — Flutter Settings -> Cloud auth token must match.
export AUTH_TOKEN="$(openssl rand -hex 32)"

docker compose up -d --build
docker compose logs -f whisper   # First run downloads the model (~30 s).
```

Hit `http://YOUR.VPS.IP:8080/healthz` and you should get
`{"status":"ok","model":"small.en","device":"cpu"}`.

## Put it behind TLS

The app refuses non-HTTPS endpoints in release builds. Put `nginx` or
`caddy` in front:

```caddy
voice.your-domain.com {
    reverse_proxy 127.0.0.1:8080
}
```

Caddy will provision a Let's Encrypt cert automatically. The Flutter
endpoint then becomes:
`https://voice.your-domain.com/api/voice/transcribe-command`

## Wiring into the Flutter app

Two equivalent options.

### Option A — set per-install via Settings UI (when you ship one)
Open *Settings → Voice → Cloud endpoint* in the app, paste
`https://voice.your-domain.com/api/voice/transcribe-command`
and the same `AUTH_TOKEN` you set above. The controller
(`QuizVoiceController._syncCloudTranscriberFromSettings`) picks it up
immediately — no rebuild required.

### Option B — bake into release builds via `--dart-define`
```bash
flutter build apk --release \
  --dart-define=CLOUD_VOICE_ENDPOINT=https://voice.your-domain.com/api/voice/transcribe-command \
  --dart-define=CLOUD_VOICE_TOKEN=$AUTH_TOKEN
```
Every install picks it up on first launch without the user typing
anything. Per-user override via Settings still works.

You must also enable cloud fallback in code or via Settings — the
`cloudFallbackEnabled` flag defaults to `false`. The simplest production
flip is to default it `true` whenever `cloudEndpointUrl` is non-empty
(suggested follow-up; not done yet to keep this change minimal).

## Model selection

| Model       | Size  | RAM | CPU latency | Best for                                  |
|-------------|-------|-----|-------------|-------------------------------------------|
| `tiny.en`   | 75 MB | 0.5 GB | ~100 ms | Smoke testing, very tight VPS              |
| `base.en`   | 145 MB | 0.8 GB | ~250 ms | Most production deployments                |
| `small.en`  | 466 MB | 1.5 GB | ~500 ms | **Default — best price/accuracy on CPU** |
| `medium.en` | 1.5 GB | 4 GB | ~1500 ms | When `small.en` mis-hears African accents  |
| `large-v3`  | 3 GB  | 8 GB | ~3000 ms (CPU) | Only with a GPU                       |

Override with `WHISPER_MODEL=base.en docker compose up -d`.

## GPU mode (optional)

```yaml
services:
  whisper:
    environment:
      WHISPER_DEVICE: cuda
      WHISPER_COMPUTE_TYPE: float16
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
```

Cuts latency to ~80 ms with `small.en`, ~150 ms with `medium.en`.

## Sanity-check the endpoint

Record a short clip and `curl` it:

```bash
curl -X POST https://voice.your-domain.com/api/voice/transcribe-command \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -F "audio=@./hello.m4a" \
  -F "locale=en-US" \
  -F "screenContext=mcq" \
  -F 'availableCommands=["a","b","c","d","next","back"]'
```

Expected:
```json
{ "transcript": "b", "confidence": 0.94, "provider": "whisper-server",
  "language": "en", "durationMs": 412 }
```

## VPS sizing

| Concurrent users | CPU             | RAM   | Notes                                      |
|------------------|------------------|-------|--------------------------------------------|
| 1 – 10           | 2 vCPU          | 2 GB  | `small.en`, int8, ~500 ms latency          |
| 10 – 50          | 4 vCPU          | 4 GB  | Same, queue depth stays under 1 s          |
| 50 – 200         | 8 vCPU or 1 GPU | 8 GB  | Switch to GPU for sub-100 ms latency       |

faster-whisper releases the GIL inside CTranslate2, so a single uvicorn
worker handles concurrent requests fine; bumping `--workers` only helps
when you also bump RAM by the model size per worker.

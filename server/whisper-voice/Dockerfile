FROM python:3.11-slim

# ffmpeg is required for faster-whisper to decode m4a/wav/mp3.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py /app/main.py

ENV WHISPER_MODEL=small.en \
    WHISPER_DEVICE=cpu \
    WHISPER_COMPUTE_TYPE=int8 \
    MAX_AUDIO_SECONDS=20 \
    MODEL_CACHE_DIR=/models \
    PYTHONUNBUFFERED=1

# Models cached here survive container restarts when this dir is a volume.
VOLUME ["/models"]

EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]

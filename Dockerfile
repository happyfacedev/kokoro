FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# System deps (espeak-ng required by kokoro for phonemization)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 python3-pip python3-dev espeak-ng git && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python deps
RUN pip install --no-cache-dir \
    "kokoro>=0.9.4" \
    soundfile \
    numpy \
    "runpod>=1.0.0" \
    torch --index-url https://download.pytorch.org/whl/cu121

# Pre-download model at build time so cold starts are fast
RUN python -c "from kokoro import KPipeline; p = KPipeline(lang_code='a'); print('Model downloaded OK')"

COPY handler.py /app/handler.py

CMD ["python", "-u", "/app/handler.py"]

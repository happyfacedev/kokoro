# Use the existing working Kokoro FastAPI image as base
FROM ghcr.io/remsky/kokoro-fastapi-gpu:latest

# Reset entrypoint to avoid conflicts with base image
ENTRYPOINT []

# Copy the serverless handler
COPY handler-wrapper.py /app/handler.py

# Switch to root to install runpod in the existing virtual environment
USER root
# Debug: Explore environment to find where things are
RUN echo "--- Environment Check ---" && \
    ls -la /app && \
    which python && \
    python --version && \
    echo "-------------------------"

# Install runpod using the detected python
# Install system dependencies (git is often needed)
RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

# Ensure pip is installed in the current python environment (venv)
# Try ensurepip first, fallback to get-pip.py
RUN python -m ensurepip --upgrade || (curl -sS https://bootstrap.pypa.io/get-pip.py | python)

# Install runpod using the detected python, bypassing PEP 668 if needed
RUN python -m pip install runpod>=1.0.0 --break-system-packages || python -m pip install runpod>=1.0.0

# Switch back to appuser
USER appuser

# Set environment variables for the wrapper
ENV PYTHONPATH=/app:/app/api
# Ensure the python we found is in path (it should be by default, but we keep the venv one just in case it exists but was missed, though likely we should just trust PATH)
# ENV PATH="/app/.venv/bin:$PATH" 
# Commenting out the forced venv path to rely on system PATH which seems to be what works for 'python'

# Point HuggingFace cache to network volume (persistent storage)
ENV HF_HOME=/runpod-volume
ENV TRANSFORMERS_CACHE=/runpod-volume
ENV HF_HUB_CACHE=/runpod-volume

# Run the serverless handler directly with unbuffered output
CMD ["python", "-u", "/app/handler.py"]

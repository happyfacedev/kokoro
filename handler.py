"""
Minimal RunPod serverless handler for Kokoro TTS.
Loads the model directly — no FastAPI wrapper needed.
"""

import base64
import io
import runpod
import soundfile as sf

print("Loading Kokoro pipeline...")
from kokoro import KPipeline
pipeline = KPipeline(lang_code='a')
print("Kokoro pipeline ready!")


def handler(job):
    """Generate speech from text and return base64 audio."""
    try:
        job_input = job.get("input", {})
        text = job_input.get("input", "") or job_input.get("text", "")
        voice = job_input.get("voice", "af_bella")
        speed = float(job_input.get("speed", 1.0))
        response_format = job_input.get("response_format", "mp3")

        if not text:
            return {"success": False, "error": "Missing 'input' or 'text' parameter"}

        # Generate audio chunks and concatenate
        import numpy as np
        audio_chunks = []
        for _, _, audio in pipeline(text, voice=voice, speed=speed):
            audio_chunks.append(audio)

        if not audio_chunks:
            return {"success": False, "error": "No audio generated"}

        audio = np.concatenate(audio_chunks)

        # Encode to requested format
        buf = io.BytesIO()
        fmt = "wav" if response_format == "wav" else "mp3"

        if fmt == "mp3":
            try:
                sf.write(buf, audio, 24000, format="mp3")
            except Exception:
                # soundfile mp3 support depends on libsndfile build; fall back to wav
                fmt = "wav"
                buf = io.BytesIO()
                sf.write(buf, audio, 24000, format="wav", subtype="PCM_16")
        else:
            sf.write(buf, audio, 24000, format="wav", subtype="PCM_16")

        audio_bytes = buf.getvalue()
        audio_base64 = base64.b64encode(audio_bytes).decode("utf-8")

        return {
            "success": True,
            "audio_base64": audio_base64,
            "format": fmt,
            "size_bytes": len(audio_bytes),
        }

    except Exception as e:
        return {"success": False, "error": str(e)}


if __name__ == "__main__":
    print("Starting RunPod serverless worker...")
    runpod.serverless.start({"handler": handler})

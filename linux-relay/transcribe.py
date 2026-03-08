import sys
import base64
import tempfile
import json
import os

from faster_whisper import WhisperModel

model = None

def get_model():
    global model
    if model is None:
        cache_dir = os.path.join(os.path.dirname(__file__), "whisper-models")
        os.makedirs(cache_dir, exist_ok=True)
        model = WhisperModel("base", device="cpu", compute_type="int8", download_root=cache_dir)
    return model

def transcribe(audio_base64):
    audio_bytes = base64.b64decode(audio_base64)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as f:
        f.write(audio_bytes)
        f.flush()
        segments, info = get_model().transcribe(f.name, beam_size=5, language=None)
        text = " ".join(seg.text.strip() for seg in segments).strip()

    skip = ["[BLANK_AUDIO]", "[NO_SPEECH]", "(silence)", ""]
    if text in skip or all(c in " ." for c in text):
        return ""
    return text

if __name__ == "__main__":
    audio_b64 = sys.stdin.read().strip()
    try:
        result = transcribe(audio_b64)
        print(json.dumps({"text": result}))
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)

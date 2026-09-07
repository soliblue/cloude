import base64
import json
import io
import os
import sys


def main():
    raw = sys.stdin.buffer.read()
    try:
        audio = base64.b64decode(raw)
    except Exception:
        print(json.dumps({"error": "decode_failed"}))
        return

    from faster_whisper import WhisperModel

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    model = WhisperModel(
        "base", device="cpu", compute_type="int8", download_root=os.path.join(root, "whisper-models")
    )

    with io.BytesIO(audio) as handle:
        segments, _ = model.transcribe(handle, beam_size=5, language=None)
        text = "".join(segment.text for segment in segments).strip()

    blanks = {"[BLANK_AUDIO]", "[NO_SPEECH]", "(silence)", ""}
    if text in blanks or all(character in ". " for character in text):
        text = ""

    print(json.dumps({"text": text}))


main()

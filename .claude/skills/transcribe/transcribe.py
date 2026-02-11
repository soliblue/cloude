#!/usr/bin/env python3
import sys
import os
import subprocess
import argparse
import time

try:
    import certifi
    os.environ.setdefault("SSL_CERT_FILE", certifi.where())
except ImportError:
    pass

SKILL_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SKILL_DIR, "output")

MODELS = {
    "tiny": "39 MB — fastest, good for clear speech",
    "base": "74 MB — fast, good default",
    "small": "244 MB — medium speed, better accuracy",
    "medium": "769 MB — slow, high accuracy",
    "large": "1.5 GB — slowest, best accuracy",
}

def ensure_whisper():
    try:
        import whisper
        return whisper
    except ImportError:
        pass
    print("Installing openai-whisper...")
    subprocess.run([sys.executable, "-m", "pip", "install", "-q", "openai-whisper"], check=True)
    import whisper
    return whisper

def ensure_ffmpeg():
    if subprocess.run(["which", "ffmpeg"], capture_output=True).returncode != 0:
        print("ERROR: ffmpeg not found. Install with: brew install ffmpeg")
        sys.exit(1)

def transcribe(file_path, model_name="large", language=None, output=None, timestamps=False):
    if not os.path.exists(file_path):
        print(f"ERROR: File not found: {file_path}")
        sys.exit(1)

    ensure_ffmpeg()
    whisper = ensure_whisper()

    import warnings
    warnings.filterwarnings("ignore", message="FP16 is not supported on CPU")

    t0 = time.time()
    print(f"Loading model '{model_name}'...")
    model = whisper.load_model(model_name)
    t_load = time.time() - t0
    print(f"Model loaded in {t_load:.1f}s")

    print(f"Transcribing: {os.path.basename(file_path)}")
    t1 = time.time()
    opts = {}
    if language:
        opts["language"] = language
    result = model.transcribe(file_path, **opts)
    t_transcribe = time.time() - t1
    print(f"Transcribed in {t_transcribe:.1f}s | Language: {result.get('language', '?')}")

    if timestamps:
        lines = []
        for seg in result["segments"]:
            start = format_time(seg["start"])
            end = format_time(seg["end"])
            lines.append(f"[{start} → {end}] {seg['text'].strip()}")
        text = "\n".join(lines)
    else:
        text = result["text"].strip()

    if output:
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        out_path = os.path.join(OUTPUT_DIR, f"{output}.txt")
        with open(out_path, "w") as f:
            f.write(text + "\n")
        print(f"\nSaved to: {out_path}")

    print(f"\n--- TRANSCRIPT ---\n{text}\n--- END ---")

def format_time(seconds):
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h}:{m:02d}:{s:02d}"
    return f"{m}:{s:02d}"

def main():
    parser = argparse.ArgumentParser(description="Transcribe audio to text with Whisper")
    parser.add_argument("file", nargs="?", help="Audio file to transcribe")
    parser.add_argument("-m", "--model", default="large", choices=list(MODELS.keys()), help="Whisper model to use")
    parser.add_argument("-l", "--language", default=None, help="Language code (e.g. en, ar, de)")
    parser.add_argument("-o", "--output", default=None, help="Output filename (without extension)")
    parser.add_argument("-t", "--timestamps", action="store_true", help="Include timestamps")
    parser.add_argument("--list-models", action="store_true", help="List available models")
    args = parser.parse_args()

    if args.list_models:
        for name, desc in MODELS.items():
            print(f"  {name:10s} {desc}")
        return

    if not args.file:
        parser.print_help()
        sys.exit(1)

    transcribe(args.file, model_name=args.model, language=args.language, output=args.output, timestamps=args.timestamps)

if __name__ == "__main__":
    main()

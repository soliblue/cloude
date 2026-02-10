#!/usr/bin/env python3
import sys
import os
import subprocess

SKILL_DIR = os.path.dirname(os.path.abspath(__file__))
VENV_DIR = os.path.join(SKILL_DIR, "venv")
MODELS_DIR = os.path.join(SKILL_DIR, "models")
OUTPUT_DIR = os.path.join(SKILL_DIR, "output")
MODEL_FILE = os.path.join(MODELS_DIR, "kokoro-v1.0.onnx")
VOICES_FILE = os.path.join(MODELS_DIR, "voices-v1.0.bin")
MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
VOICES_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"
PACKAGES = ["kokoro-onnx", "soundfile"]

def ensure_venv():
    python = os.path.join(VENV_DIR, "bin", "python3")
    if os.path.exists(python):
        return python
    print("Creating venv...")
    subprocess.run([sys.executable, "-m", "venv", VENV_DIR], check=True)
    pip = os.path.join(VENV_DIR, "bin", "pip")
    print("Installing dependencies...")
    subprocess.run([pip, "install", "-q"] + PACKAGES, check=True)
    print("Dependencies installed.")
    return python

def ensure_models():
    os.makedirs(MODELS_DIR, exist_ok=True)
    for path, url, name in [(MODEL_FILE, MODEL_URL, "model"), (VOICES_FILE, VOICES_URL, "voices")]:
        if not os.path.exists(path):
            print(f"Downloading {name} ({url.split('/')[-1]})...")
            subprocess.run(["curl", "-L", "--progress-bar", "-o", path, url], check=True)
            print(f"Downloaded {name}.")

def in_venv():
    return sys.prefix != sys.base_prefix

def reexec_in_venv(python):
    os.execv(python, [python] + sys.argv)

if not in_venv():
    python = ensure_venv()
    ensure_models()
    reexec_in_venv(python)

import argparse
import time
import soundfile as sf
from kokoro_onnx import Kokoro

VOICES = {
    "af_heart": "US Female (Heart) — default",
    "af_bella": "US Female (Bella)",
    "af_nicole": "US Female (Nicole)",
    "af_sarah": "US Female (Sarah)",
    "af_sky": "US Female (Sky)",
    "am_adam": "US Male (Adam)",
    "am_michael": "US Male (Michael)",
    "bf_emma": "UK Female (Emma)",
    "bf_isabella": "UK Female (Isabella)",
    "bm_george": "UK Male (George)",
    "bm_lewis": "UK Male (Lewis)",
}

def detect_lang(voice):
    return "en-us" if voice.startswith("a") else "en-gb"

def generate(text, voice="af_heart", speed=1.0, output=None):
    t0 = time.time()
    print(f"Loading model...")
    kokoro = Kokoro(MODEL_FILE, VOICES_FILE)
    t_load = time.time() - t0
    print(f"Model loaded in {t_load:.1f}s")

    lang = detect_lang(voice)
    print(f"Synthesizing {len(text)} chars | voice={voice} | speed={speed}x | lang={lang}")

    t1 = time.time()
    samples, sample_rate = kokoro.create(text, voice=voice, speed=speed, lang=lang)
    t_synth = time.time() - t1
    duration = len(samples) / sample_rate

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    if output is None:
        ts = time.strftime("%Y%m%d_%H%M%S")
        output = f"tts_{ts}"
    out_path = os.path.join(OUTPUT_DIR, f"{output}.wav")
    sf.write(out_path, samples, sample_rate)

    print(f"Synthesized {duration:.1f}s audio in {t_synth:.1f}s")
    print(out_path)

def main():
    parser = argparse.ArgumentParser(description="Generate speech audio with Kokoro TTS")
    parser.add_argument("text", help="Text to synthesize")
    parser.add_argument("-v", "--voice", default="af_heart", choices=list(VOICES.keys()), help="Voice to use")
    parser.add_argument("-s", "--speed", type=float, default=1.0, help="Playback speed (0.5-2.0)")
    parser.add_argument("-o", "--output", default=None, help="Output filename (without extension)")
    parser.add_argument("--list-voices", action="store_true", help="List available voices")
    args = parser.parse_args()

    if args.list_voices:
        for name, desc in VOICES.items():
            print(f"  {name:15s} {desc}")
        return

    generate(args.text, voice=args.voice, speed=args.speed, output=args.output)

if __name__ == "__main__":
    main()

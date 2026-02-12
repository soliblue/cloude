#!/usr/bin/env python3
import sys
import os
import subprocess
import argparse
import time
import json
import urllib.request
import urllib.error
import ssl

SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE

SKILL_DIR = os.path.dirname(os.path.abspath(__file__))
VENV_DIR = os.path.join(SKILL_DIR, "venv")
MODELS_DIR = os.path.join(SKILL_DIR, "models")
OUTPUT_DIR = os.path.join(SKILL_DIR, "output")
MODEL_FILE = os.path.join(MODELS_DIR, "kokoro-v1.0.onnx")
VOICES_FILE = os.path.join(MODELS_DIR, "voices-v1.0.bin")
MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
VOICES_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"
PACKAGES = ["kokoro-onnx", "soundfile"]

KOKORO_VOICES = {
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

ELEVEN_MODELS = {
    "multilingual_v2": "eleven_multilingual_v2",
    "turbo_v2_5": "eleven_turbo_v2_5",
    "turbo_v2": "eleven_turbo_v2",
    "monolingual_v1": "eleven_monolingual_v1",
    "flash_v2_5": "eleven_flash_v2_5",
}

def load_env():
    env_path = os.path.join(SKILL_DIR, ".env")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())

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

def detect_lang(voice):
    return "en-us" if voice.startswith("a") else "en-gb"

def generate_kokoro(text, voice="af_heart", speed=1.0, output=None):
    import soundfile as sf
    from kokoro_onnx import Kokoro

    t0 = time.time()
    print("Loading model...")
    kokoro = Kokoro(MODEL_FILE, VOICES_FILE)
    print(f"Model loaded in {time.time() - t0:.1f}s")

    lang = detect_lang(voice)
    print(f"Synthesizing {len(text)} chars | voice={voice} | speed={speed}x | lang={lang}")

    t1 = time.time()
    samples, sample_rate = kokoro.create(text, voice=voice, speed=speed, lang=lang)
    duration = len(samples) / sample_rate

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, f"{output or f'tts_{time.strftime("%Y%m%d_%H%M%S")}'}.wav")
    sf.write(out_path, samples, sample_rate)

    print(f"Synthesized {duration:.1f}s audio in {time.time() - t1:.1f}s")
    print(out_path)

def eleven_list_voices(api_key):
    req = urllib.request.Request(
        "https://api.elevenlabs.io/v1/voices",
        headers={"xi-api-key": api_key}
    )
    with urllib.request.urlopen(req, context=SSL_CTX) as resp:
        data = json.loads(resp.read())
    print(f"\nElevenLabs voices ({len(data['voices'])} available):\n")
    for v in sorted(data["voices"], key=lambda x: x["name"]):
        labels = v.get("labels", {})
        accent = labels.get("accent", "")
        gender = labels.get("gender", "")
        use_case = labels.get("use_case", "")
        desc = labels.get("description", "")
        tag = f"{gender}, {accent}".strip(", ")
        if use_case:
            tag += f", {use_case}"
        if desc:
            tag += f" — {desc}"
        print(f"  {v['voice_id'][:8]}...  {v['name']:20s}  ({tag})")

def generate_elevenlabs(text, voice=None, model="multilingual_v2", output=None, stability=0.4, similarity=0.8, style=0.15):
    load_env()
    api_key = os.environ.get("ELEVEN_API_KEY")
    if not api_key:
        print("ERROR: ELEVEN_API_KEY not found. Add it to .claude/skills/speak/.env")
        sys.exit(1)

    model_id = ELEVEN_MODELS.get(model, model)
    voice_id = voice or "pNInz6obpgDQGcFmaJgB"  # Adam (default)

    print(f"ElevenLabs | {len(text)} chars | model={model_id} | voice={voice_id}")
    print(f"  stability={stability} | similarity={similarity} | style={style}")

    body = json.dumps({
        "text": text,
        "model_id": model_id,
        "voice_settings": {
            "stability": stability,
            "similarity_boost": similarity,
            "style": style,
            "use_speaker_boost": True,
        }
    }).encode()

    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}",
        data=body,
        headers={
            "xi-api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        }
    )

    t0 = time.time()
    try:
        with urllib.request.urlopen(req, context=SSL_CTX) as resp:
            audio_data = resp.read()
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        print(f"ERROR {e.code}: {error_body}")
        sys.exit(1)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, f"{output or f'eleven_{time.strftime("%Y%m%d_%H%M%S")}'}.mp3")
    with open(out_path, "wb") as f:
        f.write(audio_data)

    size_kb = len(audio_data) / 1024
    print(f"Generated {size_kb:.0f}KB in {time.time() - t0:.1f}s")
    print(out_path)

def main():
    parser = argparse.ArgumentParser(description="Generate speech audio (Kokoro local or ElevenLabs cloud)")
    parser.add_argument("text", nargs="?", default="", help="Text to synthesize")
    parser.add_argument("-e", "--engine", default="kokoro", choices=["kokoro", "elevenlabs", "eleven"], help="TTS engine")
    parser.add_argument("-v", "--voice", default=None, help="Voice (kokoro: af_heart etc, elevenlabs: voice_id)")
    parser.add_argument("-s", "--speed", type=float, default=1.0, help="Speed (kokoro only, 0.5-2.0)")
    parser.add_argument("-o", "--output", default=None, help="Output filename (without extension)")
    parser.add_argument("-m", "--model", default="multilingual_v2", help="ElevenLabs model (multilingual_v2, turbo_v2_5, flash_v2_5)")
    parser.add_argument("--stability", type=float, default=0.4, help="ElevenLabs stability (0-1, lower=more expressive)")
    parser.add_argument("--similarity", type=float, default=0.8, help="ElevenLabs similarity boost (0-1)")
    parser.add_argument("--style", type=float, default=0.15, help="ElevenLabs style exaggeration (0-1)")
    parser.add_argument("--list-voices", action="store_true", help="List available voices")
    args = parser.parse_args()

    if args.engine in ("elevenlabs", "eleven"):
        if args.list_voices:
            load_env()
            api_key = os.environ.get("ELEVEN_API_KEY")
            if not api_key:
                print("ERROR: ELEVEN_API_KEY not found")
                sys.exit(1)
            eleven_list_voices(api_key)
            return
        if not args.text:
            print("ERROR: text is required")
            sys.exit(1)
        generate_elevenlabs(
            args.text, voice=args.voice, model=args.model, output=args.output,
            stability=args.stability, similarity=args.similarity, style=args.style
        )
    else:
        if args.list_voices:
            for name, desc in KOKORO_VOICES.items():
                print(f"  {name:15s} {desc}")
            return
        if not args.text:
            print("ERROR: text is required")
            sys.exit(1)
        if not in_venv():
            python = ensure_venv()
            ensure_models()
            reexec_in_venv(python)
        if args.voice is None:
            args.voice = "af_heart"
        generate_kokoro(args.text, voice=args.voice, speed=args.speed, output=args.output)

if __name__ == "__main__":
    main()

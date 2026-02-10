#!/usr/bin/env python3
import sys
import os
import subprocess

SKILL_DIR = os.path.dirname(os.path.abspath(__file__))
VENV_DIR = os.path.join(SKILL_DIR, "venv")
OUTPUT_DIR = os.path.join(SKILL_DIR, "output")
PACKAGES = ["transformers", "scipy", "torch", "soundfile"]

def ensure_venv():
    python = os.path.join(VENV_DIR, "bin", "python3")
    if os.path.exists(python):
        return python
    print("Creating venv...")
    subprocess.run([sys.executable, "-m", "venv", VENV_DIR], check=True)
    pip = os.path.join(VENV_DIR, "bin", "pip")
    print("Installing dependencies (this takes a few minutes on first run)...")
    subprocess.run([pip, "install", "-q"] + PACKAGES, check=True)
    print("Dependencies installed.")
    return python

def in_venv():
    return sys.prefix != sys.base_prefix

def reexec_in_venv(python):
    os.execv(python, [python] + sys.argv)

if not in_venv():
    python = ensure_venv()
    reexec_in_venv(python)

import argparse
import time
import numpy as np
import soundfile as sf
import torch
from transformers import AutoProcessor, MusicgenForConditionalGeneration

MODEL_ID = "facebook/musicgen-small"
SEGMENT_DURATION = 15.0

MOODS = {
    "ambient": "calm ambient electronic background music, minimal, dreamy, lo-fi",
    "upbeat": "upbeat energetic electronic music, positive, driving rhythm",
    "cinematic": "cinematic orchestral background music, epic, sweeping, emotional",
    "chill": "chill lo-fi hip hop beat, relaxed, warm, mellow",
    "dark": "dark atmospheric electronic music, moody, suspenseful, deep bass",
    "happy": "happy cheerful acoustic music, bright, playful, light",
    "focus": "minimal ambient music for concentration, soft pads, no drums, peaceful",
    "recap": "upbeat cinematic electronic music, inspiring, building momentum, modern",
}

def tokens_for_duration(seconds):
    return int(seconds * 51.2)

def crossfade(a, b, overlap_samples):
    fade_out = np.linspace(1.0, 0.0, overlap_samples, dtype=np.float32)
    fade_in = np.linspace(0.0, 1.0, overlap_samples, dtype=np.float32)
    a_end = a[-overlap_samples:] * fade_out
    b_start = b[:overlap_samples] * fade_in
    return np.concatenate([a[:-overlap_samples], a_end + b_start, b[overlap_samples:]])

def generate(prompt, duration=10.0, output=None):
    t0 = time.time()
    print(f"Loading MusicGen small ({MODEL_ID})...")
    processor = AutoProcessor.from_pretrained(MODEL_ID)
    model = MusicgenForConditionalGeneration.from_pretrained(MODEL_ID, torch_dtype=torch.float32)
    t_load = time.time() - t0
    print(f"Model loaded in {t_load:.1f}s")

    segments = []
    remaining = duration
    seg_num = 0
    t1 = time.time()

    while remaining > 0:
        seg_dur = min(SEGMENT_DURATION, remaining + 1.0)
        max_tokens = tokens_for_duration(seg_dur)
        seg_num += 1
        print(f"Segment {seg_num}: generating {seg_dur:.0f}s | tokens={max_tokens}")

        inputs = processor(text=[prompt], padding=True, return_tensors="pt")
        audio_values = model.generate(**inputs, max_new_tokens=max_tokens)
        samples = audio_values[0, 0].cpu().numpy()
        segments.append(samples)
        remaining -= SEGMENT_DURATION

    t_gen = time.time() - t1
    sample_rate = model.config.audio_encoder.sampling_rate

    if len(segments) == 1:
        final = segments[0]
    else:
        overlap = int(sample_rate * 2.0)
        final = segments[0]
        for seg in segments[1:]:
            final = crossfade(final, seg, overlap)

    target_samples = int(duration * sample_rate)
    final = final[:target_samples]
    actual_duration = len(final) / sample_rate

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    if output is None:
        ts = time.strftime("%Y%m%d_%H%M%S")
        output = f"music_{ts}"
    out_path = os.path.join(OUTPUT_DIR, f"{output}.wav")
    sf.write(out_path, final, sample_rate)

    print(f"Generated {actual_duration:.1f}s audio in {t_gen:.1f}s ({seg_num} segment{'s' if seg_num > 1 else ''})")
    print(out_path)

def main():
    parser = argparse.ArgumentParser(description="Generate music with MusicGen")
    parser.add_argument("prompt", help="Text description of the music to generate")
    parser.add_argument("-d", "--duration", type=float, default=10.0, help="Duration in seconds (default: 10)")
    parser.add_argument("-o", "--output", default=None, help="Output filename (without extension)")
    parser.add_argument("-m", "--mood", default=None, choices=list(MOODS.keys()), help="Use a preset mood instead of custom prompt")
    parser.add_argument("--list-moods", action="store_true", help="List available mood presets")
    args = parser.parse_args()

    if args.list_moods:
        for name, desc in MOODS.items():
            print(f"  {name:12s} {desc}")
        return

    prompt = MOODS[args.mood] if args.mood else args.prompt
    generate(prompt, duration=args.duration, output=args.output)

if __name__ == "__main__":
    main()

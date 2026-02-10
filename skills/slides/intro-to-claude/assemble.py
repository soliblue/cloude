import argparse
import subprocess
from pathlib import Path

BASE_DIR = Path(__file__).parent


def create_video_from_image(image_path: Path, output_path: Path, duration: float = 3.0):
    cmd = [
        "ffmpeg", "-y",
        "-loop", "1",
        "-i", str(image_path),
        "-c:v", "libx264",
        "-t", str(duration),
        "-pix_fmt", "yuv420p",
        "-vf", "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2",
        str(output_path),
    ]
    subprocess.run(cmd, check=True, capture_output=True)


def concatenate_videos(video_paths: list[Path], output_path: Path):
    concat_file = output_path.parent / "concat_list.txt"
    with open(concat_file, "w") as f:
        for video_path in video_paths:
            f.write(f"file '{video_path.resolve()}'\n")

    cmd = [
        "ffmpeg", "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", str(concat_file),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        str(output_path),
    ]
    subprocess.run(cmd, check=True, capture_output=True)
    concat_file.unlink()


def main():
    parser = argparse.ArgumentParser(description="Assemble slides and transitions into final video")
    parser.add_argument("--slides-dir", type=str, required=True, help="Directory containing slides and transitions")
    parser.add_argument("--slide-duration", type=float, default=4.0, help="How long each slide is shown (seconds)")
    parser.add_argument("--output", type=str, default="presentation.mp4", help="Output video filename")
    args = parser.parse_args()

    slides_dir = Path(args.slides_dir)
    transitions_dir = slides_dir / "transitions"
    temp_dir = slides_dir / "temp"
    temp_dir.mkdir(parents=True, exist_ok=True)

    slide_files = sorted(slides_dir.glob("slide_*.png"))
    transition_files = sorted(transitions_dir.glob("transition_*.mp4")) if transitions_dir.exists() else []

    print(f"Found {len(slide_files)} slides and {len(transition_files)} transitions")

    video_segments = []

    for i, slide_file in enumerate(slide_files):
        slide_video = temp_dir / f"slide_{i+1:02d}.mp4"
        print(f"Converting slide {i+1} to video...")
        create_video_from_image(slide_file, slide_video, args.slide_duration)
        video_segments.append(slide_video)

        if i < len(transition_files):
            video_segments.append(transition_files[i])
            print(f"Added transition {i+1}")

    output_path = slides_dir / args.output
    print(f"\nConcatenating {len(video_segments)} segments...")
    concatenate_videos(video_segments, output_path)

    for temp_file in temp_dir.glob("*.mp4"):
        temp_file.unlink()
    temp_dir.rmdir()

    print(f"\nFinal video: {output_path}")
    print(f"Duration: ~{len(slide_files) * args.slide_duration + len(transition_files) * 5:.0f} seconds")


if __name__ == "__main__":
    main()

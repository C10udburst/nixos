import argparse
import json
import os
import subprocess
import sys
import tempfile
import shutil


def check_dependencies():
    for cmd in ["ffmpeg", "ffprobe"]:
        if not shutil.which(cmd):
            print(
                f"Error: {cmd} is not installed or not in PATH.",
                file=sys.stderr
            )
            sys.exit(1)


def get_video_info(input_file):
    cmd = [
        "ffprobe",
        "-v", "quiet",
        "-print_format", "json",
        "-show_format",
        "-show_streams",
        input_file
    ]
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(
            f"Error: Failed to probe file {input_file}.",
            file=sys.stderr
        )
        if e.stderr:
            print(e.stderr, file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print(
            f"Error: Failed to parse ffprobe metadata for {input_file}.",
            file=sys.stderr
        )
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Compress a video to a target file size using 2-pass "
            "H.264/AAC encoding in a highly compatible MP4 container."
        )
    )
    parser.add_argument(
        "-i", "--input", required=True,
        help="Path to the input video file"
    )
    parser.add_argument(
        "-o", "--output",
        help=(
            "Path to the output video file "
            "(defaults to <stem>_compressed.mp4)"
        )
    )
    parser.add_argument(
        "-s", "--size", type=float, default=8.0,
        help="Target file size in MB (default: 8.0)"
    )
    parser.add_argument(
        "-y", "--overwrite", action="store_true",
        help="Overwrite output file if it already exists"
    )
    parser.add_argument(
        "--mute", action="store_true",
        help="Mute the audio stream completely in the output video"
    )

    args = parser.parse_args()

    check_dependencies()

    input_file = args.input
    if not os.path.isfile(input_file):
        print(
            f"Error: Input file '{input_file}' does not exist.",
            file=sys.stderr
        )
        sys.exit(1)

    # Determine default output file name if not provided
    if not args.output:
        base, _ = os.path.splitext(input_file)
        output_file = f"{base}_compressed.mp4"
    else:
        output_file = args.output

    if os.path.exists(output_file) and not args.overwrite:
        print(
            f"Error: Output file '{output_file}' already exists. "
            "Use -y or --overwrite to overwrite.",
            file=sys.stderr
        )
        sys.exit(1)

    print("Probing video information...")
    info = get_video_info(input_file)

    # Extract duration
    duration = None
    if "format" in info and "duration" in info["format"]:
        try:
            duration = float(info["format"]["duration"])
        except ValueError:
            pass

    # If format duration is missing/invalid, check streams
    if duration is None:
        for stream in info.get("streams", []):
            if "duration" in stream:
                try:
                    duration = float(stream["duration"])
                    break
                except ValueError:
                    pass

    if duration is None or duration <= 0:
        print("Error: Could not determine video duration.", file=sys.stderr)
        sys.exit(1)

    # Count audio streams
    audio_streams = [
        s for s in info.get("streams", [])
        if s.get("codec_type") == "audio"
    ]
    has_audio = len(audio_streams) > 0 and not args.mute

    print(f"Video duration: {duration:.2f} seconds")
    print(f"Audio stream(s) found: {len(audio_streams)}")
    if args.mute:
        print("Audio stream will be muted as requested.")

    # Target size calculations
    # 5% safety margin to account for container (MP4) muxing overhead, etc.
    safety_margin = 0.95
    target_bytes = args.size * 1024 * 1024
    budget_bytes = target_bytes * safety_margin
    budget_bits = budget_bytes * 8

    # Calculate total target bitrate
    total_bitrate_bps = budget_bits / duration

    # Determine audio and video bitrates
    audio_bitrate_bps = 0
    if has_audio:
        # Audio gets 10% of the budget, capped at 128 kbps (128000 bps)
        # Ensure a minimum of 16 kbps for audio if it is extremely low
        audio_bitrate_bps = min(128000.0, total_bitrate_bps * 0.10)
        audio_bitrate_bps = max(16000.0, audio_bitrate_bps)

    video_bitrate_bps = total_bitrate_bps - audio_bitrate_bps
    # Ensure video bitrate is at least 16 kbps
    video_bitrate_bps = max(16000.0, video_bitrate_bps)

    # Format bitrates for ffmpeg (e.g. "500k")
    video_bitrate_str = f"{int(video_bitrate_bps / 1000)}k"
    audio_bitrate_str = (
        f"{int(audio_bitrate_bps / 1000)}k" if has_audio else None
    )

    print("Encoding plan:")
    print(f"  Target size: {args.size} MB")
    print(f"  Calculated Video Bitrate: {video_bitrate_str}")
    if has_audio:
        print(f"  Calculated Audio Bitrate: {audio_bitrate_str} (AAC)")
    elif args.mute:
        print("  Audio: Muted (--mute)")
    else:
        print("  Audio: None")

    # We perform 2-pass encoding
    # Use a temporary directory for pass logfiles
    with tempfile.TemporaryDirectory() as tmpdir:
        pass_log_prefix = os.path.join(tmpdir, "ffmpeg2pass")

        # Pass 1
        pass1_cmd = [
            "ffmpeg",
            "-y",
            "-i", input_file,
            "-c:v", "libx264",
            "-b:v", video_bitrate_str,
            "-pass", "1",
            "-passlogfile", pass_log_prefix,
            "-an",
            "-f", "null",
            os.devnull
        ]

        # Pass 2
        pass2_cmd = [
            "ffmpeg",
            "-y",
            "-i", input_file,
            "-c:v", "libx264",
            "-b:v", video_bitrate_str,
            "-pass", "2",
            "-passlogfile", pass_log_prefix,
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart"
        ]

        if has_audio:
            pass2_cmd.extend(["-c:a", "aac", "-b:a", audio_bitrate_str])
        else:
            pass2_cmd.append("-an")

        pass2_cmd.append(output_file)

        print("\n--- Starting Pass 1/2 ---")
        try:
            subprocess.run(pass1_cmd, check=True)
        except subprocess.CalledProcessError:
            print("Error: ffmpeg Pass 1 failed.", file=sys.stderr)
            sys.exit(1)

        print("\n--- Starting Pass 2/2 ---")
        try:
            subprocess.run(pass2_cmd, check=True)
        except subprocess.CalledProcessError:
            print("Error: ffmpeg Pass 2 failed.", file=sys.stderr)
            sys.exit(1)

    print(f"\nCompression complete! Output saved to: {output_file}")
    if os.path.exists(output_file):
        actual_size = os.path.getsize(output_file) / (1024 * 1024)
        print(f"Actual output size: {actual_size:.2f} MB")


if __name__ == "__main__":
    main()

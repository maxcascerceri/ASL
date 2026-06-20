#!/usr/bin/env python3
"""Extract grid poster JPEGs from bundled MP4s so colors match playback.

Some filmmaker batches (notably Elijah) were shot with very low chroma. A still
JPEG at grid size can look duller than the same clip in AVPlayer even when both
come from the same MP4. We probe each frame and apply a capped saturation boost
only when measured chroma is below the Victoria batch baseline.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_TIMESTAMP_SECONDS = 0.15
DEFAULT_MAX_PIXEL_SIZE = 480
DEFAULT_JPEG_QUALITY = 2
PROBE_WIDTH = 160
CHROMA_BOOST_THRESHOLD = 18.0
TARGET_CHROMA = 28.0
MAX_SATURATION_BOOST = 2.5


def filmed_word_ids(repo_root: Path) -> list[str]:
    catalog = repo_root / "ASL" / "Shared" / "FilmedSignCatalog.swift"
    if not catalog.exists():
        raise FileNotFoundError(f"Missing filmed catalog: {catalog}")
    return sorted(set(re.findall(r'"([a-z0-9]+)"', catalog.read_text(encoding="utf-8"))))


def resolve_ffmpeg(explicit: str | None) -> str | None:
    if explicit:
        return explicit
    found = shutil.which("ffmpeg")
    if found:
        return found
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return None


def build_video_filter(max_pixel_size: int, saturation: float) -> str:
    filters = [
        f"scale={max_pixel_size}:{max_pixel_size}:force_original_aspect_ratio=decrease"
    ]
    if abs(saturation - 1.0) > 0.01:
        filters.append(f"eq=saturation={saturation:.3f}")
    return ",".join(filters)


def extract_frame(
    ffmpeg: str,
    source_mp4: Path,
    destination: Path,
    timestamp: float,
    video_filter: str,
    *,
    jpeg_quality: int | None = None,
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = [
        ffmpeg,
        "-y",
        "-ss",
        str(timestamp),
        "-i",
        str(source_mp4),
        "-frames:v",
        "1",
        "-vf",
        video_filter,
    ]
    if jpeg_quality is not None:
        command.extend(["-q:v", str(jpeg_quality)])
    command.append(str(destination))
    subprocess.run(command, check=True, capture_output=True)


def parse_ppm_rgb(path: Path) -> list[tuple[int, int, int]]:
    data = path.read_bytes()
    if not data.startswith(b"P6"):
        raise ValueError(f"Expected binary PPM (P6), got: {path}")

    offset = 3
    header_numbers: list[int] = []
    while len(header_numbers) < 3:
        while offset < len(data) and data[offset] in b" \t\r\n":
            offset += 1
        if offset < len(data) and data[offset] == ord("#"):
            while offset < len(data) and data[offset] != ord("\n"):
                offset += 1
            continue
        end = offset
        while end < len(data) and data[end] not in b" \t\r\n":
            end += 1
        token = data[offset:end].decode("ascii")
        offset = end
        for part in token.split():
            header_numbers.append(int(part))
            if len(header_numbers) == 3:
                break

    width, height, maxval = header_numbers
    while offset < len(data) and data[offset] in b" \t\r\n":
        offset += 1

    if maxval != 255:
        raise ValueError(f"Expected 8-bit PPM probe output, got maxval={maxval}")

    pixels = data[offset : offset + width * height * 3]
    return [
        (pixels[index], pixels[index + 1], pixels[index + 2])
        for index in range(0, len(pixels), 3)
    ]


def measure_chroma(rgb: list[tuple[int, int, int]]) -> float:
    if not rgb:
        return 0.0
    total = sum(max(r, g, b) - min(r, g, b) for r, g, b in rgb)
    return total / len(rgb)


def saturation_boost(
    chroma: float,
    *,
    threshold: float,
    target: float,
    max_boost: float,
) -> float:
    if chroma >= threshold:
        return 1.0
    return min(max_boost, target / max(chroma, 0.1))


def probe_chroma(
    ffmpeg: str,
    source_mp4: Path,
    timestamp: float,
    probe_width: int,
) -> float:
    with tempfile.TemporaryDirectory() as tmp:
        probe_path = Path(tmp) / "probe.ppm"
        extract_frame(
            ffmpeg,
            source_mp4,
            probe_path,
            timestamp,
            f"scale={probe_width}:-2,format=rgb24",
        )
        return measure_chroma(parse_ppm_rgb(probe_path))


def extract_poster(
    ffmpeg: str,
    source_mp4: Path,
    destination_jpg: Path,
    timestamp: float,
    max_pixel_size: int,
    jpeg_quality: int,
    *,
    chroma_threshold: float,
    target_chroma: float,
    max_saturation_boost: float,
    disable_chroma_boost: bool,
) -> float:
    saturation = 1.0
    if not disable_chroma_boost:
        chroma = probe_chroma(ffmpeg, source_mp4, timestamp, PROBE_WIDTH)
        saturation = saturation_boost(
            chroma,
            threshold=chroma_threshold,
            target=target_chroma,
            max_boost=max_saturation_boost,
        )

    extract_frame(
        ffmpeg,
        source_mp4,
        destination_jpg,
        timestamp,
        build_video_filter(max_pixel_size, saturation),
        jpeg_quality=jpeg_quality,
    )
    return saturation


def should_regenerate(
    poster_path: Path,
    video_path: Path,
    *,
    force: bool,
) -> bool:
    if force:
        return True
    if not poster_path.exists() or poster_path.stat().st_size == 0:
        return True
    if not video_path.exists():
        return False
    return video_path.stat().st_mtime > poster_path.stat().st_mtime


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--videos-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "ASL" / "BundledMedia" / "Videos",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "ASL" / "BundledMedia" / "Posters",
    )
    parser.add_argument("--timestamp", type=float, default=DEFAULT_TIMESTAMP_SECONDS)
    parser.add_argument("--max-pixel-size", type=int, default=DEFAULT_MAX_PIXEL_SIZE)
    parser.add_argument("--jpeg-quality", type=int, default=DEFAULT_JPEG_QUALITY)
    parser.add_argument("--chroma-threshold", type=float, default=CHROMA_BOOST_THRESHOLD)
    parser.add_argument("--target-chroma", type=float, default=TARGET_CHROMA)
    parser.add_argument("--max-saturation-boost", type=float, default=MAX_SATURATION_BOOST)
    parser.add_argument(
        "--no-chroma-boost",
        action="store_true",
        help="Disable automatic saturation correction for low-chroma footage.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerate every poster that has a bundled MP4.",
    )
    parser.add_argument("--ffmpeg", default=None, help="Path to ffmpeg binary.")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ffmpeg = resolve_ffmpeg(args.ffmpeg)
    if not ffmpeg and not args.dry_run:
        print("ffmpeg not found on PATH or via imageio-ffmpeg", file=sys.stderr)
        raise SystemExit(1)

    word_ids = filmed_word_ids(args.repo_root)
    args.output_dir.mkdir(parents=True, exist_ok=True)

    generated = 0
    skipped = 0
    missing_video = 0
    failed = 0
    boosted = 0

    for index, word_id in enumerate(word_ids, start=1):
        video_path = args.videos_dir / f"{word_id}.mp4"
        poster_path = args.output_dir / f"{word_id}.jpg"

        if not video_path.exists() or video_path.stat().st_size == 0:
            missing_video += 1
            print(f"skip {word_id}: missing bundled MP4", file=sys.stderr)
            continue

        if not should_regenerate(poster_path, video_path, force=args.force):
            skipped += 1
            continue

        if args.dry_run:
            print(f"would extract {word_id} from {video_path.name}")
            generated += 1
            continue

        try:
            saturation = extract_poster(
                ffmpeg,
                video_path,
                poster_path,
                args.timestamp,
                args.max_pixel_size,
                args.jpeg_quality,
                chroma_threshold=args.chroma_threshold,
                target_chroma=args.target_chroma,
                max_saturation_boost=args.max_saturation_boost,
                disable_chroma_boost=args.no_chroma_boost,
            )
            if saturation > 1.01:
                boosted += 1
            generated += 1
            if index % 50 == 0:
                print(f"extracted {index}/{len(word_ids)}…")
        except subprocess.CalledProcessError as exc:
            failed += 1
            print(
                f"failed {word_id}: {exc.stderr.decode(errors='ignore')}",
                file=sys.stderr,
            )

    print(
        f"Done: {len(word_ids)} filmed signs, "
        f"{generated} posters generated ({boosted} saturation-boosted), "
        f"{skipped} up-to-date, {missing_video} missing MP4, {failed} failures"
    )
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

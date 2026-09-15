#!/bin/bash
# Downsample genuine 4K capture; never upscale a lower-resolution source.
set -euo pipefail
video_root="$(cd "$(dirname "$0")/../.." && pwd)"
video_output="${1:-$video_root/output/angle-aiming-video-20260915}"
for video_mode in 2d 3d; do
  video_source="$video_output/angle-aiming-$video_mode-4k.mp4"
  video_dimensions="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$video_source")"
  if [[ "$video_dimensions" != '2160x3840' ]]; then
    echo "Expected genuine 2160x3840 master: $video_source ($video_dimensions)" >&2
    exit 1
  fi
  for video_tier in 2k 1k; do
    case "$video_tier" in
      2k) video_size=1440:2560 ;;
      1k) video_size=1080:1920 ;;
    esac
    ffmpeg -hide_banner -loglevel warning -y -i "$video_source" \
      -map 0:v:0 -an -vf "scale=$video_size:flags=lanczos" \
      -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart \
      "$video_output/angle-aiming-$video_mode-$video_tier.mp4"
  done
done

#!/bin/bash
# Opt-in simulator capture. Opening/bridge and full atlas are independent exports.
set -euo pipefail
capture_root="$(cd "$(dirname "$0")/../.." && pwd)"
capture_mode="${1:-keyframes}"
capture_device="${2:?Usage: capture-separation-intro.sh keyframes|opening|simulation SIMULATOR_UDID [OUTPUT_DIR]}"
capture_output="${3:-$capture_root/output/separation-intro-20260916/r3}"
capture_build="${SEPARATION_CAPTURE_BUILD_DIR:-$capture_output/build}"
case "$capture_mode" in
  keyframes) capture_test=testKeyframes ;;
  opening) capture_test=testExportBoth ;;
  simulation) capture_test=testExportSimulation ;;
  *) echo 'Mode must be keyframes, opening or simulation' >&2; exit 2 ;;
esac
mkdir -p "$capture_output"
cd "$capture_root"
TEST_RUNNER_SEPARATION_INTRO_DIR="$capture_output" make -f scripts/Makefile test \
  BUILD_DIR="$capture_build" TEST_LOG="$capture_output/$capture_mode-build.log" \
  TEST_DESTINATION="platform=iOS Simulator,id=$capture_device" TEST_CODE_COVERAGE=NO \
  TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO' \
  ONLY_TESTING="QiuJiTests/SeparationIntroVideoCaptureTests/$capture_test"
if [[ "$capture_mode" == simulation ]]; then
  # Keep the original validated angle sampling, then accelerate only presentation.
  ffmpeg -hide_banner -loglevel error -y -i "$capture_output/simulation-source-silent.mp4" \
    -vf "setpts='if(lt(T,0.5),PTS,if(lt(T,14.5),(0.5+(T-0.5)/2.8)/TB,(5.5+T-14.5)/TB))',fps=60" \
    -frames:v 360 -an -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart \
    "$capture_output/02-simulation-silent.mp4"
fi

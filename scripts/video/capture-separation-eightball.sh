#!/bin/bash
# One incoming cue ball, then eight production simulations aligned at object contact.
set -euo pipefail
capture_root="$(cd "$(dirname "$0")/../.." && pwd)"
capture_mode="${1:-preview}"
capture_device="${2:?Usage: capture-separation-eightball.sh preview|video SIMULATOR_UDID [OUTPUT_DIR]}"
capture_output="${3:-$capture_root/output/separation-eightball-20260916/r3}"
case "$capture_mode" in
  preview) capture_preview=1 ;;
  video) capture_preview=0 ;;
  *) echo 'Mode must be preview or video' >&2; exit 2 ;;
esac
mkdir -p "$capture_output"
cd "$capture_root"
TEST_RUNNER_EIGHT_BALL_VIDEO_DIR="$capture_output" TEST_RUNNER_EIGHT_BALL_PREVIEW="$capture_preview" \
  make -f scripts/Makefile test BUILD_DIR="${EIGHT_BALL_CAPTURE_BUILD_DIR:-$capture_output/build}" \
  TEST_LOG="$capture_output/$capture_mode-build.log" \
  TEST_DESTINATION="platform=iOS Simulator,id=$capture_device" TEST_CODE_COVERAGE=NO \
  TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO' \
  ONLY_TESTING=QiuJiTests/SeparationEightBallVideoCaptureTests/testExport

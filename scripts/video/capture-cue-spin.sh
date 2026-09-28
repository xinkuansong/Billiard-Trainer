#!/bin/bash
set -euo pipefail
capture_root="$(cd "$(dirname "$0")/../.." && pwd)"
capture_mode="${1:-keyframes}"
capture_device="${2:?Usage: capture-cue-spin.sh keyframes|video UDID OUTPUT [BUILD_DIR]}"
capture_output="${3:?Specify an absolute output directory}"
capture_build="${4:-$capture_output/build}"
case "$capture_mode" in
  keyframes) capture_video=0 ;;
  video) capture_video=1 ;;
  *) echo 'Unknown mode' >&2; exit 2 ;;
esac
mkdir -p "$capture_output"
cd "$capture_root"
TEST_RUNNER_CUE_SPIN_DIR="$capture_output" TEST_RUNNER_CUE_SPIN_VIDEO="$capture_video" \
make -f scripts/Makefile test BUILD_DIR="$capture_build" TEST_LOG="$capture_output/build.log" \
  TEST_DESTINATION="platform=iOS Simulator,id=$capture_device" TEST_CODE_COVERAGE=NO \
  TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO' \
  ONLY_TESTING=QiuJiTests/CueSpinPreviewCaptureTests/testCapture

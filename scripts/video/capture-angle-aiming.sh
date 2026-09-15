#!/bin/bash
# Reproducible, opt-in simulator SceneKit capture. Normal app behavior is untouched.
set -euo pipefail
capture_root="$(cd "$(dirname "$0")/../.." && pwd)"
capture_mode="${1:-keyframes}"
capture_device="${2:?Usage: capture-angle-aiming.sh keyframes|2d|3d SIMULATOR_UDID [OUTPUT_DIR]}"
capture_output="${3:-$capture_root/output/angle-aiming-video-20260915}"
case "$capture_mode" in
  keyframes) capture_test=testGeometryAndKeyframes ;;
  2d) capture_test=testExport2D ;;
  3d) capture_test=testExport3D ;;
  *) echo 'Mode must be keyframes, 2d or 3d' >&2; exit 2 ;;
esac
mkdir -p "$capture_output"
cd "$capture_root"
TEST_RUNNER_ANGLE_CAPTURE_DIR="$capture_output" make -f scripts/Makefile test \
  BUILD_DIR="$capture_output/build" TEST_LOG="$capture_output/$capture_mode-build.log" \
  TEST_DESTINATION="platform=iOS Simulator,id=$capture_device" TEST_CODE_COVERAGE=NO \
  TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO' \
  ONLY_TESTING="QiuJiTests/AngleAimingVideoCaptureTests/$capture_test"

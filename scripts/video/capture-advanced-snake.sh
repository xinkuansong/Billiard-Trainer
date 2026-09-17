#!/bin/bash
set -euo pipefail
capture_root="$(cd "$(dirname "$0")/../.." && pwd)"
capture_mode="${1:-keyframes}"
capture_device="${2:?Usage: capture-advanced-snake.sh preflight|keyframes|transitions|export SIMULATOR_UDID [OUTPUT_DIR]}"
capture_output="${3:-$capture_root/output/advanced-snake-video-20260916/r2}"
case "$capture_mode" in
  preflight) capture_test=testPreflight ;;
  keyframes) capture_test=testKeyframes ;;
  export) capture_test=testExport ;;
  transitions) capture_test=testTransitions ;;
  *) echo 'Mode must be preflight, keyframes, transitions or export' >&2; exit 2 ;;
esac
mkdir -p "$capture_output"
cd "$capture_root"
TEST_RUNNER_SNAKE_CAPTURE_DIR="$capture_output" make -f scripts/Makefile test \
  BUILD_DIR="$capture_output/build" TEST_LOG="$capture_output/$capture_mode-build.log" \
  TEST_DESTINATION="platform=iOS Simulator,id=$capture_device" TEST_CODE_COVERAGE=NO \
  TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO' \
  ONLY_TESTING="QiuJiTests/AdvancedSnakeVideoCaptureTests/$capture_test"

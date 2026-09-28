#!/bin/bash
set -euo pipefail
capture_root="$(cd "$(dirname "$0")/../.." && pwd)"
capture_mode="${1:-keyframes}"
capture_device="${2:?Usage: capture-feel-aiming.sh geometry|candidates|keyframes|export UDID OUTPUT [BUILD_DIR]}"
capture_output="${3:?Specify a dedicated output directory}"
capture_build="${4:-$capture_output/build}"
case "$capture_mode" in
  geometry) capture_test=testGeometry ;;
  candidates) capture_test=testCameraCandidates ;;
  keyframes) capture_test=testKeyframes ;;
  export) capture_test=testExport ;;
  *) echo 'Unknown capture mode' >&2; exit 2 ;;
esac
mkdir -p "$capture_output"
cd "$capture_root"
TEST_RUNNER_FEEL_AIM_DIR="$capture_output" make -f scripts/Makefile test \
  BUILD_DIR="$capture_build" TEST_LOG="$capture_output/$capture_mode-build.log" \
  TEST_DESTINATION="platform=iOS Simulator,id=$capture_device" TEST_CODE_COVERAGE=NO \
  TEST_ACTION="${FEEL_TEST_ACTION:-test}" \
  TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO' \
  ONLY_TESTING="QiuJiTests/FeelAimingVideoCaptureTests/$capture_test"

#!/bin/bash
# Native App preview of a previously verified two-shot solution.
set -euo pipefail
video_root="$(cd "$(dirname "$0")/../.." && pwd)"
video_mode="${1:?stills|export}"
video_device="${2:?Simulator UDID}"
video_solution="${3:?Absolute solution JSON}"
video_out="${4:?Fresh output directory}"
case "$video_mode" in stills) video_export=0;; export) video_export=1;; *) exit 2;; esac
mkdir -p "$video_out"
video_out="$(cd "$video_out" && pwd)"
[[ ! -e "$video_out/build.log" ]] || { echo 'Use a fresh output directory' >&2; exit 2; }
cd "$video_root"
cp "$video_solution" "$video_out/solution.json"
cp QiuJiTests/SixPocketTwoShotTests.swift "$video_out/source.swift"
TEST_RUNNER_TWO_SHOT_VIDEO_DIR="$video_out" \
TEST_RUNNER_TWO_SHOT_VIDEO_SOLUTION="$video_out/solution.json" \
TEST_RUNNER_TWO_SHOT_VIDEO_EXPORT="$video_export" \
make -f scripts/Makefile test DERIVED_DATA="$video_root/build/DerivedData-v63-w17c" \
  TEST_LOG="$video_out/build.log" TEST_DESTINATION="platform=iOS Simulator,id=$video_device" \
  TEST_CODE_COVERAGE=NO \
  TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO SWIFT_OPTIMIZATION_LEVEL=-O' \
  ONLY_TESTING='QiuJiTests/SixPocketTwoShotTests/testTwoShotVideo'
rg -q 'Test Case .*testTwoShotVideo.*passed' "$video_out/build.log"
rg -q 'Executed [1-9][0-9]* tests?, with 0 failures' "$video_out/build.log"

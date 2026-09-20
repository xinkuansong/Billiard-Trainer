#!/bin/bash
set -euo pipefail
two_root="$(cd "$(dirname "$0")/../.." && pwd)"
two_mode="${1:?Usage: run-two-shot.sh validate|coverage SIMULATOR_UDID OUTPUT_DIR}"
two_device="${2:?Simulator UDID required}"
two_out="${3:?Fresh output directory required}"
case "$two_mode" in
  validate) two_test=testStateHandoffAndValidation ;;
  coverage) two_test=testCoverageSearch ;;
  *) exit 2 ;;
esac
mkdir -p "$two_out"
two_out="$(cd "$two_out" && pwd)"
if [[ -e "$two_out/build.log" ]]; then echo 'Use a fresh output directory' >&2; exit 2; fi
cd "$two_root"
cp QiuJiTests/SixPocketTwoShotTests.swift "$two_out/source.swift"
shasum -a 256 QiuJi/Core/Physics/*.swift QiuJiTests/SixPocketTwoShotTests.swift > "$two_out/sources.sha256"
python3 - "$two_out" "$two_device" <<'PY'
import json,os,sys
from pathlib import Path
Path(sys.argv[1],'run-config.json').write_text(json.dumps(dict(
    device=sys.argv[2],distanceMetres=0.12772500514984131,cueSpeedCap=8,
    seed=os.getenv('TWO_SHOT_SEED','20260920'),budget=os.getenv('TWO_SHOT_BUDGET','18000'),
    seconds=os.getenv('TWO_SHOT_SECONDS','120'),starts=os.getenv('TWO_SHOT_STARTS'),
    bank=os.getenv('TWO_SHOT_BANK'),solutions=os.getenv('TWO_SHOT_SOLUTIONS'),model='appDefault',targetCushionLimit=2,
    cueJawForbidden=True),indent=2))
for key,name in [('TWO_SHOT_STARTS','input-starts.json'),('TWO_SHOT_BANK','input-bank.json'),('TWO_SHOT_SOLUTIONS','input-solutions.json')]:
    if os.getenv(key): Path(sys.argv[1],name).write_bytes(Path(os.environ[key]).read_bytes())
PY
if [[ -n "${TWO_SHOT_STARTS:-}" ]]; then export TEST_RUNNER_TWO_SHOT_STARTS="$TWO_SHOT_STARTS"; fi
if [[ -n "${TWO_SHOT_BANK:-}" ]]; then export TEST_RUNNER_TWO_SHOT_BANK="$TWO_SHOT_BANK"; fi
if [[ -n "${TWO_SHOT_SOLUTIONS:-}" ]]; then export TEST_RUNNER_TWO_SHOT_SOLUTIONS="$TWO_SHOT_SOLUTIONS"; fi
TEST_RUNNER_TWO_SHOT_DIR="$two_out" \
TEST_RUNNER_TWO_SHOT_BUDGET="${TWO_SHOT_BUDGET:-18000}" \
TEST_RUNNER_TWO_SHOT_SECONDS="${TWO_SHOT_SECONDS:-120}" \
TEST_RUNNER_TWO_SHOT_SEED="${TWO_SHOT_SEED:-20260920}" \
make -f scripts/Makefile test DERIVED_DATA="$two_root/build/DerivedData-v63-w17c" \
  TEST_LOG="$two_out/build.log" TEST_DESTINATION="platform=iOS Simulator,id=$two_device" \
  TEST_CODE_COVERAGE=NO \
  TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO SWIFT_OPTIMIZATION_LEVEL=-O' \
  ONLY_TESTING="QiuJiTests/SixPocketTwoShotTests/$two_test"
rg -q "Test Case .*SixPocketTwoShotTests.*$two_test.*passed" "$two_out/build.log"
rg -q 'Executed [1-9][0-9]* tests?, with 0 failures' "$two_out/build.log"

#!/bin/zsh
set -eu
cd /Users/song/projects/13.billiard_trainer
name="$1"
selector="$2"
role="${3:-standard-phone}"
selectors=""
for item in "${(@s:,:)selector}"; do
 [[ "$item" == CuePhysTests/* || "$item" == CuePhysUITests/* ]]
 selectors+=" -only-testing:$item"
done
run=output/local-test-runs/63cb30bfa1644915bbe3c85a4377214a
[[ ! -e "$run/evidence/$name.xcresult" ]]
python3 scripts/simulator_fleet.py run --role "$role" --task "v73-$name" -- python3 scripts/spatial-quiz/with-booted.py '{udid}' make -f scripts/Makefile _test \
 TEST_DESTINATION='platform=iOS Simulator,id={udid}' BUILD_DIR="$run/work" DERIVED_DATA="${V73_DERIVED_DATA:-$run/work/B5DerivedData}" \
 TEST_LOG="$run/evidence/$name.log" TEST_JUNIT="$run/evidence/$name.xml" TEST_RESULT_BUNDLE="$run/evidence/$name.xcresult" \
 TEST_SELECTOR="$selectors" TEST_ACTION=test-without-building TEST_CODE_COVERAGE=NO TEST_BUILD_SETTINGS='-collect-test-diagnostics never'

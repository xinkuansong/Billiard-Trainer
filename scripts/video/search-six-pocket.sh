#!/bin/bash
set -euo pipefail
search_root="$(cd "$(dirname "$0")/../.." && pwd)"
search_mode="${1:?Usage: search-six-pocket.sh fixture|survey|uniform|audit|distribution|scheduler|regions|adaptive|scene|fixed|free|route|terminal|constrained|contact|power|local|optimize|replay SIMULATOR_UDID [OUTPUT_DIR] [SECONDS]}"
search_device="${2:?Simulator UDID required}"
search_output="${3:-$search_root/output/six-pocket-one-shot-20260917/$search_mode}"
search_seconds="${4:-180}"
case "$search_mode" in
  fixture) search_test=testFixture; search_fixed=1 ;;
  audit) search_test=testFeasibilityAudit; search_fixed=0 ;;
  distribution) search_test=testAdaptiveDistribution; search_fixed=0 ;;
  scheduler) search_test=testRegionTreeScheduler; search_fixed=0 ;;
  regions) search_test=testRegionComparison; search_fixed=0 ;;
  adaptive) search_test=testAdaptiveFeasibilitySearch; search_fixed=0 ;;
  uniform) search_test=testUniformSearch; search_fixed=0 ;;
  survey) search_test=testUniformSurvey; search_fixed=0 ;;
  scene) search_test=testFixtureScene; search_fixed=1 ;;
  fixed) search_test=testSearch; search_fixed=1 ;;
  free) search_test=testSearch; search_fixed=0 ;;
  terminal) search_test=testTerminalConstraint; search_fixed=0 ;;
  constrained) search_test=testConstrainedSearch; search_fixed=0 ;;
  route) search_test=testRouteSearch; search_fixed=0 ;;
  contact) search_test=testContactSearch; search_fixed=0 ;;
  power) search_test=testPowerSweep; search_fixed=0 ;;
  local) search_test=testLocalSearch; search_fixed=0 ;;
  optimize) search_test=testOptimize; search_fixed=0 ;;
  replay) search_test=testReplay; search_fixed=0 ;;
  input-audit) search_test=testReplayInputAudit; search_fixed=0 ;;
  video) search_test=testFiveBallVideo; search_fixed=0 ;;
  *) echo 'Mode must be fixture, scene, fixed, free, route, contact, power, local, optimize or replay' >&2; exit 2 ;;
esac
mkdir -p "$search_output"
cd "$search_root"
cp QiuJiTests/SixPocketSearchTests.swift "$search_output/search-source.swift"
shasum -a 256 QiuJi/Core/Physics/*.swift > "$search_output/physics-sources.sha256"
TEST_RUNNER_SIX_SEARCH_DIR="$search_output" \
TEST_RUNNER_SIX_FIXED_CUE="$search_fixed" \
TEST_RUNNER_SIX_SEARCH_SECONDS="$search_seconds" \
make -f scripts/Makefile test \
  DERIVED_DATA="$search_root/build/DerivedData-v63-w17c" TEST_LOG="$search_output/build.log" \
  TEST_DESTINATION="platform=iOS Simulator,id=$search_device" TEST_CODE_COVERAGE=NO \
  TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO SWIFT_OPTIMIZATION_LEVEL=-O' \
  ONLY_TESTING="QiuJiTests/SixPocketSearchTests/$search_test"

if ! rg -q "Executed [1-9][0-9]* tests?," "$search_output/build.log"; then
  echo "Selected search test did not execute; inspect $search_output/build.log" >&2
  exit 1
fi

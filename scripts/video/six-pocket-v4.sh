#!/bin/bash
# V011 "one shot, six pocket-side balls" — v4 phase 0/2 runner.
# Read-only research probes against the production engine. Never edit this script while a run
# is in flight, and give every round its own output directory.
set -euo pipefail
v4_root="$(cd "$(dirname "$0")/../.." && pwd)"
v4_mode="${1:?Usage: six-pocket-v4.sh cushion-map|fixture|potmap|collision|cushion|reach|longrun|arc|collision2|rail|polyline|refine|population|artifacts|replay SIMULATOR_UDID [OUTPUT_DIR]}"
v4_device="${2:?Simulator UDID required}"

case "$v4_mode" in
  cushion-map) v4_class=SixPocketV4ProbeTests; v4_test=testCushionIndexMap; v4_phase=phase0 ;;
  fixture)     v4_class=SixPocketV4ProbeTests; v4_test=testDistanceLadderFixture; v4_phase=phase0 ;;
  potmap)      v4_class=SixPocketV4ProbeTests; v4_test=testPotMap; v4_phase=phase0 ;;
  collision)   v4_class=SixPocketV4ProbeTests; v4_test=testCollisionResponse; v4_phase=phase0 ;;
  cushion)     v4_class=SixPocketV4ProbeTests; v4_test=testCushionReflection; v4_phase=phase0 ;;
  reach)       v4_class=SixPocketV4ProbeTests; v4_test=testPostCollisionReach; v4_phase=phase0 ;;
  # Round 2 (FL-079): state-seeded probes — two-phase energy, arcs, dense collision/rail maps.
  longrun)     v4_class=SixPocketV4Round2ProbeTests; v4_test=testLongFreeRun; v4_phase=round2/phase0 ;;
  arc)         v4_class=SixPocketV4Round2ProbeTests; v4_test=testFreeArcTable; v4_phase=round2/phase0 ;;
  collision2)  v4_class=SixPocketV4Round2ProbeTests; v4_test=testCollisionMap; v4_phase=round2/phase0 ;;
  rail)        v4_class=SixPocketV4Round2ProbeTests; v4_test=testRailMap; v4_phase=round2/phase0 ;;
  polyline)    v4_class=SixPocketV4Round2ProbeTests; v4_test=testMultiRailPolyline; v4_phase=round2/phase0 ;;
  refine)      v4_class=SixPocketV4RefineTests; v4_test=testCellRefinement; v4_phase=phase2 ;;
  # Spec v5 (five balls): route-archive population search over the same seven controls.
  population)  v4_class=SixPocketV4RefineTests; v4_test=testPopulationSearch; v4_phase=phase2 ;;
  artifacts)   v4_class=SixPocketV4RefineTests; v4_test=testSolutionArtifacts; v4_phase=phase2 ;;
  replay)      v4_class=SixPocketV4RefineTests; v4_test=testProductionReplay; v4_phase=phase2 ;;
  *) echo 'Mode must be cushion-map, fixture, potmap, collision, cushion, reach, longrun, arc, collision2, rail, polyline, refine, population, artifacts or replay' >&2; exit 2 ;;
esac

v4_output="${3:-$v4_root/output/six-pocket-one-shot-20260917/v4/$v4_phase/$v4_mode}"
mkdir -p "$v4_output"
cd "$v4_root"
cp "QiuJiTests/$v4_class.swift" "$v4_output/probe-source.swift"
shasum -a 256 QiuJi/Core/Physics/*.swift "QiuJiTests/$v4_class.swift" > "$v4_output/sources.sha256"

TEST_RUNNER_SIX_V4_DIR="$v4_output" \
TEST_RUNNER_SIX_V4_SOURCE_SHA256="$v4_output/sources.sha256" \
TEST_RUNNER_SIX_V4_PLAN_JSON="${SIX_V4_PLAN_JSON:-}" \
TEST_RUNNER_SIX_V4_MAX_CUE_SPEED="${SIX_V4_MAX_CUE_SPEED:-8}" \
TEST_RUNNER_SIX_V4_SIM_BUDGET="${SIX_V4_SIM_BUDGET:-600}" \
TEST_RUNNER_SIX_V4_SECONDS="${SIX_V4_SECONDS:-1800}" \
TEST_RUNNER_SIX_V4_BEST_JSON="${SIX_V4_BEST_JSON:-}" \
TEST_RUNNER_SIX_V4_PHI_STEP_DEGREES="${SIX_V4_PHI_STEP_DEGREES:-1}" \
TEST_RUNNER_SIX_V4_PHI_LIMIT_DEGREES="${SIX_V4_PHI_LIMIT_DEGREES:-45}" \
TEST_RUNNER_SIX_V4_SPEED_STEP="${SIX_V4_SPEED_STEP:-0.25}" \
TEST_RUNNER_SIX_V4_SPEED_MAX="${SIX_V4_SPEED_MAX:-6}" \
TEST_RUNNER_SIX_V5_SECONDS="${SIX_V5_SECONDS:-900}" \
TEST_RUNNER_SIX_V5_SIMS="${SIX_V5_SIMS:-400000}" \
TEST_RUNNER_SIX_V5_SEED="${SIX_V5_SEED:-1}" \
TEST_RUNNER_SIX_V5_RESUME="${SIX_V5_RESUME:-}" \
TEST_RUNNER_SIX_V6_ELITE="${SIX_V6_ELITE:-0}" \
make -f scripts/Makefile test \
  DERIVED_DATA="${SIX_DERIVED_DATA:-$v4_root/build/DerivedData-v63-w17c}" TEST_LOG="$v4_output/build.log" \
  TEST_DESTINATION="platform=iOS Simulator,id=$v4_device" TEST_CODE_COVERAGE=NO \
  TEST_BUILD_SETTINGS='CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO SWIFT_OPTIMIZATION_LEVEL=-O' \
  ONLY_TESTING="QiuJiTests/$v4_class/$v4_test"

if ! rg -q "Executed [1-9][0-9]* tests?," "$v4_output/build.log"; then
  echo "Selected v4 probe did not execute; inspect $v4_output/build.log" >&2
  exit 1
fi

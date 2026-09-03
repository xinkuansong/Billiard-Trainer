#!/bin/zsh

set -euo pipefail

if [[ $# -ne 1 ]]; then
  print -u2 "usage: $0 <booted-simulator-udid>"
  exit 64
fi

repo_dir="/Users/song/projects/13.billiard_trainer"
pilot_dir="$repo_dir/tmp/cover-semantic-validation/20260831-pilot"
output_dir="$pilot_dir/output/simulator"
simulator_udid="$1"
backup_dir="$(mktemp -d /tmp/qiuji-cover-pilot-assets.XXXXXX)"

asset_names=(
  coverPlanPositioning
  coverPlanAccuracy3
  coverPlanFullskill
  coverPracticeSpinAndEnglish
  coverPracticeSeparationAtlas
  coverPracticeDiamond
)

asset_paths=(
  "QiuJi/Resources/Assets.xcassets/Atmosphere/coverPlanPositioning.imageset/coverPlanPositioning.png"
  "QiuJi/Resources/Assets.xcassets/Atmosphere/coverPlanAccuracy3.imageset/coverPlanAccuracy3.png"
  "QiuJi/Resources/Assets.xcassets/Atmosphere/coverPlanFullskill.imageset/coverPlanFullskill.png"
  "QiuJi/Resources/Assets.xcassets/Atmosphere/coverPracticeSpinAndEnglish.imageset/coverPracticeSpinAndEnglish.png"
  "QiuJi/Resources/Assets.xcassets/Atmosphere/coverPracticeSeparationAtlas.imageset/coverPracticeSeparationAtlas.png"
  "QiuJi/Resources/Assets.xcassets/Atmosphere/coverPracticeDiamond.imageset/coverPracticeDiamond.png"
)

restore_assets() {
  local index
  for index in {1..${#asset_paths[@]}}; do
    cp "$backup_dir/${asset_names[$index]}.png" "$repo_dir/${asset_paths[$index]}"
  done
  print "RESTORED: six formal Asset Catalog PNGs"
}

trap restore_assets EXIT INT TERM

mkdir -p "$output_dir/light" "$output_dir/dark"

for index in {1..${#asset_paths[@]}}; do
  cp "$repo_dir/${asset_paths[$index]}" "$backup_dir/${asset_names[$index]}.png"
  cp "$pilot_dir/output/${asset_names[$index]}.png" "$repo_dir/${asset_paths[$index]}"
done
print "INSTALLED: six pilot covers temporarily"

cd "$repo_dir"
make -f scripts/Makefile build

for appearance in light dark; do
  print "CAPTURE: $appearance"
  xcrun simctl ui "$simulator_udid" appearance "$appearance"

  if [[ "$appearance" == "light" ]]; then
    practice_test="testW3HomeCoverLightScreenshots"
  else
    practice_test="testW3HomeCoverDarkScreenshots"
  fi

  xcodebuild test \
    -project QiuJi.xcodeproj \
    -scheme QiuJi \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    -derivedDataPath build/cover-pilot-derived \
    -only-testing:"QiuJiUITests/W3_HomeCoverUITests/$practice_test"

  cp "$repo_dir/build/w3-screenshots/w3-c20-01-home-all-$appearance.png" \
    "$output_dir/$appearance/practice-01-home-all.png"
  cp "$repo_dir/build/w3-screenshots/w3-c20-02-home-learn-$appearance.png" \
    "$output_dir/$appearance/practice-02-home-learn.png"
  cp "$repo_dir/build/w3-screenshots/w3-c20-03-home-train-$appearance.png" \
    "$output_dir/$appearance/practice-03-home-train.png"
  cp "$repo_dir/build/w3-screenshots/w3-c20-04-home-solve-$appearance.png" \
    "$output_dir/$appearance/practice-04-home-solve.png"

  xcodebuild test \
    -project QiuJi.xcodeproj \
    -scheme QiuJi \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    -derivedDataPath build/cover-pilot-derived \
    -only-testing:QiuJiUITests/V37W4PlanShelfUITests/testCoverPilotTargetCards

  cp "$repo_dir/build/v38-w7-screenshots/pilot-plan_accuracy3.png" \
    "$output_dir/$appearance/plan-01-accuracy3.png"
  cp "$repo_dir/build/v38-w7-screenshots/pilot-plan_positioning.png" \
    "$output_dir/$appearance/plan-02-positioning.png"
  cp "$repo_dir/build/v38-w7-screenshots/pilot-plan_fullskill.png" \
    "$output_dir/$appearance/plan-03-fullskill.png"
done

print "PASS: Light/Dark App trial captures completed"

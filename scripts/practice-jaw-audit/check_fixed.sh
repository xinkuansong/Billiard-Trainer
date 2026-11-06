#!/bin/bash
set -eu
work=output/four-jaw-full-20261106
# Wait for this task's generic compile; the fleet correctly excludes simultaneous undirected Xcode jobs.
while ! rg -q 'BUILD (SUCCEEDED|FAILED)' "$work/sep/build.log"; do sleep 5; done
python3 scripts/simulator_fleet.py run --role compact-phone-floor --task pocket-jaw-final-host -- python3 scripts/practice-jaw-audit/host_sequence.py '{udid}' "$work" kball bank

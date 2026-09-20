#!/usr/bin/env python3
"""Turn a round-2 `plan2.py` rung file into the plan JSON `SixPocketV4RefineTests` reads.

The phase-2 refiner was written against round 1's plan format: rows carrying the seven one-shot
control values (`cueStartXZ`, `aimRadians`, `cueSpeed`, `spinX`, `spinY`) plus the impact parameter
each ball is meant to be hit with. Round 2's planner carries the cue's *physical* state
(speed, rolling ratio, english in rad/s) instead, because that is what the measured maps are
indexed on, so the opening state has to be converted back into tip offsets here.

Conversion, from `CueBallStrike.cueStrikePT` with a level cue (theta = 0):

    ball speed      v = 2·V0 / (1 + m/M)            -> measured gain 1.357, so V0 = v / 1.357
    rolling ratio   ω·R/v = 2.5·b                   -> b = rollRatio / 2.5
    english (yUp)   ω_up = −2.5·a·v/R               -> a = −english·R / (2.5·v)

Both offsets are clamped to `CuePhysics.miscueLimitFraction` (0.5). The clamp means the requested
spin is not always reproducible by a legal strike — which is exactly why this is only a starting
point: phase 2 optimises the seven real control values against the engine and judges success from
engine events alone.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from plan import BALLS, Measurements  # noqa: E402

BALL_RADIUS = 0.028574999421834946
MISCUE_LIMIT = 0.5
CUE_TO_BALL_SPEED_GAIN = 1.357  # round-1 probe D, `phase0/collision/`
CUE_SPEED_CAP = 8.0


def clamp(value, limit):
    return max(-limit, min(limit, value))


def tip_offsets(ball_speed, roll_ratio, english):
    vertical = clamp(roll_ratio / 2.5, MISCUE_LIMIT)
    horizontal = 0.0
    if ball_speed > 1e-6:
        horizontal = clamp(-english * BALL_RADIUS / (2.5 * ball_speed), MISCUE_LIMIT)
    # Joint miscue limit: the offset magnitude, not each component, is what the cue tip is bound by.
    magnitude = math.hypot(horizontal, vertical)
    if magnitude > MISCUE_LIMIT:
        horizontal *= MISCUE_LIMIT / magnitude
        vertical *= MISCUE_LIMIT / magnitude
    return horizontal, vertical


def row_from_chain(entry, closed):
    chain = entry["chain"]
    head = chain[0]
    if "cueStartXZ" not in head or "openingAimRadians" not in head:
        return None
    ball_speed = head.get("openingSeedSpeed", 0.0)
    spin_x, spin_y = tip_offsets(ball_speed, head.get("openingSeedRollRatio", 0.0),
                                 head.get("openingSeedEnglish", 0.0))
    return {
        "order": entry["order"],
        "ballsChained": entry.get("depth", len(chain)),
        "closed": closed,
        "cueStartXZ": head["cueStartXZ"],
        "aimRadians": head["openingAimRadians"],
        "cueSpeed": min(CUE_SPEED_CAP, ball_speed / CUE_TO_BALL_SPEED_GAIN),
        "spinX": spin_x,
        "spinY": spin_y,
        "phis": [node["lineOfCentresOffsetDegrees"] for node in chain],
        "events": [{"kind": "ballBall", "ball": node["ball"],
                    "impactParameterInBallRadii": node["impactParameterInBallRadii"]}
                   for node in chain],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase0", required=True, help="round-1 phase-0 root (pot map, fixture)")
    parser.add_argument("--plan2", required=True, help="a plan2-rungN.json")
    parser.add_argument("--rung", type=int, required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--pot-map-dir", default="")
    parser.add_argument("--pot-window", default="clean", choices=sorted(Measurements.POT_WINDOW_KEYS))
    args = parser.parse_args()

    with open(args.plan2, "r", encoding="utf-8") as handle:
        plan = json.load(handle)
    measurements = Measurements(args.phase0, pot_map_dir=args.pot_map_dir or None,
                                pot_window=args.pot_window)
    # Spec v5: the plan file records which ball was left off the table; the refiner needs it so it
    # places five balls and requires five pots, and it must come from the plan rather than a
    # separate flag that could disagree with the geometry the chains were planned on.
    omit = int(plan.get("omitBall") or 0)
    acceptance = {}
    for ball in BALLS:
        if ball == omit:
            continue
        runs, _, _ = measurements.acceptance(args.rung, ball)
        acceptance[str(ball)] = [[lo, hi] for lo, hi in runs]

    rows_closed = [r for r in (row_from_chain(e, True) for e in plan.get("closableOrders", [])) if r]
    rows_open = [r for r in (row_from_chain(e, False) for e in plan.get("deepestChains", [])) if r]
    out = {
        "rung": args.rung,
        "omitBall": omit,
        "distanceMetres": plan["distanceMetres"],
        "acceptanceIntervalsDegrees": acceptance,
        "closableOrders": rows_closed,
        "deepestPartialChains": rows_open,
        "note": ("adapted from round-2 plan2 output by adapt2.py; cue tip offsets are inverted from "
                 "the planner's physical spin state through the production strike model and clamped "
                 "to the miscue limit, so they are a starting point, not a claim"),
        "source": os.path.abspath(args.plan2),
    }
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(out, handle, indent=2, sort_keys=True)
    print("rung %d: %d closed + %d partial chains -> %s"
          % (args.rung, len(rows_closed), len(rows_open), args.out))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Phase 1 of the v4 "one shot, six pocket-side balls" study: topology and geometry planning.

Reads only the phase-0 engine measurements (pot map, collision response, cushion reflection,
fixture ladder) and never calls the engine. Output per distance rung: the visiting orders whose
six-collision chain closes geometrically, an idealised initial vector u0 for each, and — when a
rung closes nothing — the per-segment failure statistics that constitute the "this rung is not
feasible" evidence required by v4 clause 2.

Coordinate contract (identical to the engine): SceneKit XZ horizontal, Y up, metres;
portrait screen up = +X, right = +Z. Everything here works in the XZ plane only.

Chain model, all numbers taken from phase 0:
  * A struck target leaves along the line of centres. It pots cleanly only if that direction
    lies in the measured clean acceptance interval around the ball→hole-centre direction.
  * Fixing that direction fixes the ghost-ball point G = P - 2R * (unit line of centres), so
    one angle per ball parametrises the whole chain.
  * The cue leaves a collision along the tangent (perpendicular to the line of centres) and then
    bends. Probe C's 0.3 s window puts that bend at ≤11°, but probe E, which follows the cue over
    a whole segment, measures chord deviations up to ~107°. The planner therefore does not use a
    fixed allowance: for every segment it queries probe E's reach table with the required chord
    (length, deviation from tangent) and reads back the arrival speed, the arrival travel
    direction (which sets the next impact parameter) and how far the real curved path bulges away
    from the chord (which is added to the clearance margin).
  * Cue speed after a collision = incoming speed * the measured ratio at that impact parameter;
    free running loses speed at the measured deceleration; each straight-rail bounce keeps the
    measured retention fraction.
"""

from __future__ import annotations

import argparse
import itertools
import json
import math
import os
from bisect import bisect_left

BALL_RADIUS = 0.028575
BALL_DIAMETER = 0.05715
# Pocket hole centres, TablePhysics: corner offset (1.27 + 0.042, 0.635 + 0.042),
# side centre z = 0.63296474 + 0.043. Cross-checked below against the phase-0 fixture file.
CORNER_X, CORNER_Z, SIDE_Z = 1.312, 0.677, 0.67596474
CORNER_R, SIDE_R = 0.042, 0.043
POCKETS = {
    "pocket_0": (-CORNER_X, -CORNER_Z, CORNER_R, True),
    "pocket_1": (CORNER_X, -CORNER_Z, CORNER_R, True),
    "pocket_2": (-CORNER_X, CORNER_Z, CORNER_R, True),
    "pocket_3": (CORNER_X, CORNER_Z, CORNER_R, True),
    "pocket_4": (0.0, -SIDE_Z, SIDE_R, False),
    "pocket_5": (0.0, SIDE_Z, SIDE_R, False),
}
BALL_POCKET = {1: "pocket_1", 2: "pocket_3", 3: "pocket_5", 4: "pocket_2", 5: "pocket_0", 8: "pocket_4"}
BALLS = [1, 2, 3, 4, 5, 8]
# Mirror symmetries of the layout; used to compress the 720 visiting orders.
MIRROR_X = {1: 5, 5: 1, 2: 4, 4: 2, 3: 3, 8: 8}
MIRROR_Z = {1: 2, 2: 1, 4: 5, 5: 4, 3: 8, 8: 3}
MIRROR_XZ = {b: MIRROR_Z[MIRROR_X[b]] for b in BALLS}


# --------------------------------------------------------------------------- vector helpers

def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def scale(a, k):
    return (a[0] * k, a[1] * k)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1]


def cross(a, b):
    return a[0] * b[1] - a[1] * b[0]


def norm(a):
    return math.hypot(a[0], a[1])


def unit(a):
    n = norm(a)
    return (a[0] / n, a[1] / n) if n > 1e-12 else (0.0, 0.0)


def from_angle(t):
    return (math.cos(t), math.sin(t))


def angle_of(a):
    return math.atan2(a[1], a[0])


def signed_angle(a, b):
    """Signed angle from a to b, degrees."""
    return math.degrees(math.atan2(cross(a, b), dot(a, b)))


def point_segment_distance(p, a, b):
    d = sub(b, a)
    l2 = dot(d, d)
    t = 0.0 if l2 <= 0 else max(0.0, min(1.0, dot(sub(p, a), d) / l2))
    return norm(sub(p, add(a, scale(d, t))))


def segment_segment_distance(p1, p2, q1, q2):
    """Minimum distance between two segments in the plane."""
    d1, d2 = sub(p2, p1), sub(q2, q1)
    denom = cross(d1, d2)
    if abs(denom) > 1e-15:
        t = cross(sub(q1, p1), d2) / denom
        u = cross(sub(q1, p1), d1) / denom
        if 0 <= t <= 1 and 0 <= u <= 1:
            return 0.0
    return min(point_segment_distance(p1, q1, q2), point_segment_distance(p2, q1, q2),
               point_segment_distance(q1, p1, p2), point_segment_distance(q2, p1, p2))


# --------------------------------------------------------------------------- phase-0 inputs

class Measurements:
    """The three transfer functions plus the layout, all read from phase-0 JSON."""

    # Pot-window flavours measured by probe B. "clean" is spec clause 3a (no cushion at all before
    # dropping); "v41" is clause 3b (own pocket after at most two of the ball's own cushion events).
    POT_WINDOW_KEYS = {"clean": "cleanIntervalsDegrees", "v41": "v41IntervalsDegrees"}

    def __init__(self, phase0: str, speed_tolerance=0.25, length_tolerance=0.05, angle_tolerance=4.0,
                 pot_map_dir=None, pot_window="clean"):
        self.phase0 = phase0
        if pot_window not in self.POT_WINDOW_KEYS:
            raise SystemExit("pot_window must be one of %s" % sorted(self.POT_WINDOW_KEYS))
        self.pot_window = pot_window
        self.pot_window_key = self.POT_WINDOW_KEYS[pot_window]
        # Phase 1 is a candidate generator, not a verdict: these are how loosely a segment may
        # match a measured sample before phase 2 takes over with the real engine and LM refinement.
        self.speed_tolerance = speed_tolerance
        self.length_tolerance = length_tolerance
        self.angle_tolerance = angle_tolerance
        self.fixture = self._read(os.path.join(phase0, "fixture", "fixture-ladder", "fixture-ladder.json"))
        self.cushion_map = self._read(os.path.join(phase0, "cushion-map", "cushion-index-map.json"))
        self.collision = self._read(os.path.join(phase0, "collision", "collision-response",
                                                 "collision-response.json"))
        self.reflection = self._read(os.path.join(phase0, "cushion", "cushion-reflection",
                                                 "cushion-reflection.json"))
        self.reach_rows = self._read(os.path.join(phase0, "reach", "post-collision-reach",
                                                 "post-collision-reach.json"))
        self.pot_map_dir = pot_map_dir or os.path.join(phase0, "potmap", "pot-map")
        self.pot_maps = {}
        for rung in range(5):
            path = os.path.join(self.pot_map_dir, "pot-map-rung%d.json" % rung)
            self.pot_maps[rung] = self._read(path)
        missing = [rung for rung in self.pot_maps
                   if self.pot_window_key not in self.pot_maps[rung]["balls"][0]["cleanAcceptanceBySpeed"][0]]
        if missing:
            raise SystemExit("pot map in %s has no '%s' field (rerun testPotMap)"
                             % (self.pot_map_dir, self.pot_window_key))
        self._verify_layout()
        self._build_collision_tables()
        self._build_rail_tables()
        self._build_reach_table()

    @staticmethod
    def _read(path):
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)

    def _verify_layout(self):
        """Coordinate contract check: our pocket constants must reproduce the measured distances."""
        for rung in self.fixture:
            for ball in rung["balls"]:
                px, pz, _, _ = POCKETS[ball["pocket"]]
                measured = ball["distanceToHoleCentreMetres"]
                recomputed = math.hypot(ball["xz"][0] - px, ball["xz"][1] - pz)
                if abs(measured - recomputed) > 1e-6:
                    raise SystemExit("pocket constant mismatch for %s: %.9f vs %.9f"
                                     % (ball["pocket"], measured, recomputed))
                if BALL_POCKET[ball["ball"]] != ball["pocket"]:
                    raise SystemExit("ball/pocket mapping mismatch for ball %d" % ball["ball"])

    # -- collision response R -------------------------------------------------

    def _build_collision_tables(self):
        """|b|/R -> (cue speed ratio, target speed ratio, tangent-deviation spread)."""
        buckets = {}
        for row in self.collision:
            if not row.get("contacted"):
                continue
            key = round(abs(row["measuredImpactParameterInBallRadii"]), 2)
            entry = buckets.setdefault(key, {"cue": [], "target": [], "dev": []})
            entry["cue"].append(row["cueSpeedRatio"])
            entry["target"].append(row["targetSpeedRatio"])
            if row["cueDeviationFromTangentDegrees"] != -999:
                entry["dev"].append(row["cueDeviationFromTangentDegrees"])
        self.impact_keys = sorted(buckets)
        self.cue_ratio = [sum(buckets[k]["cue"]) / len(buckets[k]["cue"]) for k in self.impact_keys]
        self.target_ratio = [sum(buckets[k]["target"]) / len(buckets[k]["target"]) for k in self.impact_keys]
        devs = [d for k in buckets for d in buckets[k]["dev"] if 0.3 <= k < 1.7]
        self.measured_tangent_spread = max(abs(min(devs)), abs(max(devs))) if devs else 0.0
        # Cue tip speed -> ball speed straight after the strike.
        ratios = [row["launchBallSpeed"] / row["cueSpeed"] for row in self.collision
                  if row.get("contacted") and row["cueSpeed"] > 0]
        self.strike_speed_gain = sum(ratios) / len(ratios)

    def _interp(self, table, b_over_r):
        x = min(max(abs(b_over_r), self.impact_keys[0]), self.impact_keys[-1])
        i = bisect_left(self.impact_keys, x)
        if i == 0:
            return table[0]
        if i >= len(self.impact_keys):
            return table[-1]
        x0, x1 = self.impact_keys[i - 1], self.impact_keys[i]
        w = 0.0 if x1 == x0 else (x - x0) / (x1 - x0)
        return table[i - 1] * (1 - w) + table[i] * w

    def cue_speed_ratio(self, b_over_r):
        return self._interp(self.cue_ratio, b_over_r)

    def target_speed_ratio(self, b_over_r):
        return self._interp(self.target_ratio, b_over_r)

    # -- free run and cushion F ----------------------------------------------

    @staticmethod
    def _deceleration_samples(row):
        """v_launch^2 - v_before^2 = 2 a L over the measured straight approach."""
        v0 = row.get("launchBallSpeed")
        v1 = row.get("incomingBallSpeed")
        length = row.get("preContactPathLengthMetres")
        if not v0 or not v1 or not length or length < 0.05 or v0 <= v1:
            return []
        return [(v0 * v0 - v1 * v1) / (2 * length)]

    def _build_rail_tables(self):
        """Straight-rail retention, mirror deviation spread, and free-run deceleration.

        Deceleration is recovered from the same samples: the launch point, the measured speed at
        the cushion and the launch ball speed give one v^2 = v0^2 - 2 a L estimate per sample.
        """
        retention, deviation, decel = [], [], []
        for row in self.reflection:
            if not row.get("usable") or not row.get("hitIntendedRail"):
                continue
            retention.append(row["speedRetention"])
            deviation.append(row["deviationFromMirrorDegrees"])
            decel.extend(self._deceleration_samples(row))
        for row in self.collision:
            if row.get("contacted"):
                decel.extend(self._deceleration_samples(row))
        self.rail_retention = sorted(retention)[len(retention) // 2]
        self.rail_deviation_spread = max(abs(min(deviation)), abs(max(deviation)))
        decel.sort()
        # One effective deceleration for a run that is part sliding and part rolling. This is a
        # planning approximation; phase 2 uses the engine's own integration.
        self.deceleration = decel[len(decel) // 2] if decel else 1.96
        # A handful of samples sit far off the median (very short or interrupted runs), so the
        # reported band is the 5th-95th percentile rather than the raw extremes.
        if decel:
            self.deceleration_range = (decel[int(0.05 * (len(decel) - 1))],
                                       decel[int(0.95 * (len(decel) - 1))])
            self.deceleration_samples = len(decel)
        else:
            self.deceleration_range, self.deceleration_samples = (1.96, 1.96), 0
        # Straight-rail geometry, taken from the measured cushion index map.
        self.straight_rails = []
        for segment in self.cushion_map["segments"]:
            if segment["kind"] == "linear" and segment["straightRail"]:
                self.straight_rails.append({
                    "index": segment["index"], "start": tuple(segment["start"]),
                    "end": tuple(segment["end"]), "normal": tuple(segment["normal"])})
        # Everything the cue may not touch (jaw lines, jaw arcs, throat and back walls),
        # flattened into segments; arcs are sampled because they are short. They all sit around a
        # pocket, so they are bucketed by their nearest pocket: a path far from every pocket
        # skips the whole test.
        forbidden = []
        for segment in self.cushion_map["segments"]:
            if segment["kind"] == "linear" and not segment["straightRail"]:
                forbidden.append((tuple(segment["start"]), tuple(segment["end"])))
            elif segment["kind"] == "circular":
                cx, cz = segment["center"]
                r = segment["radius"]
                a0 = math.radians(segment["startAngleDegrees"])
                a1 = math.radians(segment["endAngleDegrees"])
                steps = 8
                points = [(cx + r * math.cos(a0 + (a1 - a0) * i / steps),
                           cz + r * math.sin(a0 + (a1 - a0) * i / steps)) for i in range(steps + 1)]
                forbidden.extend(zip(points, points[1:]))
        self.forbidden = forbidden
        self.forbidden_by_pocket = {name: [] for name in POCKETS}
        self.forbidden_reach = {name: 0.0 for name in POCKETS}
        for a, b in forbidden:
            mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
            owner = min(POCKETS, key=lambda n: math.hypot(mid[0] - POCKETS[n][0], mid[1] - POCKETS[n][1]))
            px, pz = POCKETS[owner][0], POCKETS[owner][1]
            self.forbidden_by_pocket[owner].append((a, b))
            self.forbidden_reach[owner] = max(self.forbidden_reach[owner],
                                              math.hypot(a[0] - px, a[1] - pz),
                                              math.hypot(b[0] - px, b[1] - pz))
        if sum(len(v) for v in self.forbidden_by_pocket.values()) != len(forbidden):
            raise SystemExit("forbidden cushion bucketing is not a partition")

    # -- post-collision reach set (probe E) -----------------------------------

    SPEED_BUCKET = 0.25          # m/s, index granularity on the post-contact cue speed
    LENGTH_BUCKET = 0.1          # m, index granularity on the chord length

    def _build_reach_table(self):
        """Index probe E's flat table by (post-contact speed, chord length) for segment queries.

        Every row is one cushion-free sample of a real post-collision run: where the cue got to
        (chord length and its deviation from the tangent), how fast and in which direction it was
        travelling there, and how far the curved path bulged away from the chord.
        """
        columns = {name: i for i, name in enumerate(self.reach_rows["columns"])}
        # Bucketed on (post-contact speed, chord length, chord deviation rounded to a degree).
        # Within a bucket the samples are near-duplicates, so only two representatives are kept:
        # the straightest path (smallest bulge, easiest to clear obstacles) and the fastest
        # arrival (most energy left for the rest of the chain). This turns a 235k-row scan into a
        # handful of dictionary hits per segment.
        self.reach = {}
        self.reach_samples = 0
        for row in self.reach_rows["rows"]:
            v_out = row[columns["postContactCueSpeed"]]
            length = row[columns["chordLengthMetres"]]
            deviation = row[columns["chordDeviationFromTangentDegrees"]]
            sample = {"postContactSpeed": v_out, "chordLength": length,
                      "chordDeviationDegrees": deviation,
                      "arrivalDirectionDegrees": row[columns["arrivalDirectionFromTangentDegrees"]],
                      "arrivalSpeed": row[columns["arrivalSpeed"]],
                      "bulge": row[columns["pathBulgeMetres"]],
                      "spin": (row[columns["spinX"]], row[columns["spinY"]]),
                      "impactParameterInBallRadii": row[columns["measuredImpactParameterInBallRadii"]]}
            key = (int(v_out / self.SPEED_BUCKET), int(length / self.LENGTH_BUCKET),
                   int(round(deviation)))
            kept = self.reach.get(key)
            if kept is None:
                self.reach[key] = [sample, sample]
                self.reach_samples += 1
                continue
            if sample["bulge"] < kept[0]["bulge"]:
                kept[0] = sample
            if sample["arrivalSpeed"] > kept[1]["arrivalSpeed"]:
                kept[1] = sample
        if not self.reach_samples:
            raise SystemExit("probe E produced no usable reach samples")
        # Secondary index: which chord deviations exist at all for a (speed, length) cell.
        self.reach_deviations = {}
        for (i, j, k) in self.reach:
            self.reach_deviations.setdefault((i, j), []).append(k)

    def reach_query(self, speed, length, deviation_degrees, speed_tolerance=None,
                    length_tolerance=None, angle_tolerance=None):
        """Samples that get the cue from a collision to a point `length` away, `deviation` off the
        tangent, starting at roughly `speed`.         Empty list means the segment is not reachable."""
        speed_tolerance = self.speed_tolerance if speed_tolerance is None else speed_tolerance
        length_tolerance = self.length_tolerance if length_tolerance is None else length_tolerance
        angle_tolerance = self.angle_tolerance if angle_tolerance is None else angle_tolerance
        lo = int((speed / (1 + speed_tolerance)) / self.SPEED_BUCKET)
        hi = int((speed * (1 + speed_tolerance)) / self.SPEED_BUCKET)
        tol_l = max(length_tolerance, 0.05 * length)
        j0 = int((length - tol_l) / self.LENGTH_BUCKET)
        j1 = int((length + tol_l) / self.LENGTH_BUCKET)
        k0 = int(math.floor(deviation_degrees - angle_tolerance))
        k1 = int(math.ceil(deviation_degrees + angle_tolerance))
        found = []
        for i in range(lo, hi + 1):
            for j in range(j0, j1 + 1):
                for k in range(k0, k1 + 1):
                    for sample in self.reach.get((i, j, k), ()):
                        if abs(sample["chordLength"] - length) > tol_l:
                            continue
                        if abs(sample["chordDeviationDegrees"] - deviation_degrees) > angle_tolerance:
                            continue
                        found.append(sample)
        return found

    def reach_deviation_window(self, speed, length, speed_tolerance=0.25, length_tolerance=0.05):
        """Chord deviations probe E ever produced at roughly this speed and chord length.

        Used to turn an unreachable segment into a number: how many degrees short of the nearest
        measured departure the geometry was asking for.
        """
        speed_tolerance = self.speed_tolerance if speed_tolerance is None else speed_tolerance
        length_tolerance = self.length_tolerance if length_tolerance is None else length_tolerance
        lo = int((speed / (1 + speed_tolerance)) / self.SPEED_BUCKET)
        hi = int((speed * (1 + speed_tolerance)) / self.SPEED_BUCKET)
        tol_l = max(length_tolerance, 0.05 * length)
        j0 = int((length - tol_l) / self.LENGTH_BUCKET)
        j1 = int((length + tol_l) / self.LENGTH_BUCKET)
        window = []
        for i in range(lo, hi + 1):
            for j in range(j0, j1 + 1):
                window.extend(self.reach_deviations.get((i, j), ()))
        return window

    # -- pot map P ------------------------------------------------------------

    def acceptance(self, rung, ball):
        """Clean acceptance intervals in degrees for one ball, intersected over all probed speeds.

        Intersecting is the conservative reading: the planner does not yet know the arrival speed
        to within a bucket, and the measured intervals turned out to be nearly speed independent.
        """
        for row in self.pot_maps[rung]["balls"]:
            if row["ball"] != ball:
                continue
            per_speed = [row["cleanAcceptanceBySpeed"][i][self.pot_window_key]
                         for i in range(len(row["cleanAcceptanceBySpeed"]))]
            common = None
            for intervals in per_speed:
                covered = set()
                for lo, hi in intervals:
                    covered.update(range(int(round(lo)), int(round(hi)) + 1))
                common = covered if common is None else (common & covered)
            degrees = sorted(common or [])
            runs = []
            for degree in degrees:
                if runs and degree == runs[-1][1] + 1:
                    runs[-1][1] = degree
                else:
                    runs.append([degree, degree])
            return runs, row["baseDirectionRadians"], tuple(row["xz"])
        raise KeyError(ball)

    def ball_positions(self, rung):
        return {b["ball"]: tuple(b["xz"]) for b in self.fixture[rung]["balls"]}


# --------------------------------------------------------------------------- chain propagation

class Planner:
    def __init__(self, m: Measurements, rung: int, phi_step: float,
                 cue_speed_cap: float, node_budget: int, cut_step: float = 10.0):
        self.m = m
        self.rung = rung
        self.phi_step = phi_step
        steps = max(1, int(round(60.0 / cut_step)))
        self.cut_samples = [20.0 + i * 60.0 / steps for i in range(steps + 1)]
        self.cue_speed_cap = cue_speed_cap
        self.node_budget = node_budget
        self.nodes = 0
        self.positions = m.ball_positions(rung)
        self.acceptance = {}
        self.base_direction = {}
        for ball in BALLS:
            runs, base, _ = m.acceptance(rung, ball)
            self.acceptance[ball] = runs
            self.base_direction[ball] = base
        # Lowest probed speed that still pots cleanly, per ball; at the tight rungs this is the
        # bottom of the probed grid, i.e. the pot map found no speed floor above 0.25 m/s.
        self.min_pot_speed_by_ball = {}
        for row in m.pot_maps[rung]["balls"]:
            speeds = [s["speed"] for s in row["cleanAcceptanceBySpeed"] if s[m.pot_window_key]]
            self.min_pot_speed_by_ball[row["ball"]] = min(speeds) if speeds else float("inf")
        self.min_pot_speed = max(self.min_pot_speed_by_ball.values())
        self.current = {}
        self.reached = 0
        self.partials = {}
        self.partials_per_depth = 6

    # -- primitives -----------------------------------------------------------

    def phi_samples(self, ball):
        out = []
        for lo, hi in self.acceptance[ball]:
            steps = max(1, int(math.floor((hi - lo) / self.phi_step)))
            for i in range(steps + 1):
                out.append(lo + i * (hi - lo) / steps)
        return out

    def ghost(self, ball, phi_degrees):
        """Cue-centre point at contact, and the line-of-centres unit vector."""
        line = from_angle(self.base_direction[ball] + math.radians(phi_degrees))
        p = self.positions[ball]
        return sub(p, scale(line, 2 * BALL_RADIUS)), line

    def clear_of_forbidden(self, a, b, margin=0.0):
        """Cue centre must stay a radius clear of every jaw line, jaw arc and throat wall.

        `margin` widens the corridor by the bulge of the real curved path around the chord.
        """
        for name, (px, pz, _, _) in POCKETS.items():
            reach = self.m.forbidden_reach[name] + BALL_RADIUS + margin
            if point_segment_distance((px, pz), a, b) > reach:
                continue
            for q1, q2 in self.m.forbidden_by_pocket[name]:
                if segment_segment_distance(a, b, q1, q2) <= BALL_RADIUS + margin:
                    return False
        return True

    def clear_of_balls(self, a, b, allowed, margin=0.0):
        for ball, p in self.positions.items():
            if ball in allowed:
                continue
            if point_segment_distance(p, a, b) <= 2 * BALL_RADIUS + margin:
                return False
        return True

    def clear_of_pockets(self, a, b, allowed_pockets, margin=0.0):
        for name, (px, pz, r, _) in POCKETS.items():
            if name in allowed_pockets:
                continue
            if point_segment_distance((px, pz), a, b) <= r + margin:
                return False
        return True

    def route_options(self, start, target, allowed_balls, allowed_pockets, tangent, speed):
        """Ways for the cue centre to get from `start` to `target` after a collision.

        The chord is fixed by geometry, so the question is whether probe E ever saw the cue cover
        that chord from that speed. Each answer carries its own arrival direction, arrival speed
        and bulge, so one chord can yield several options.
        """
        chord = sub(target, start)
        length = norm(chord)
        if length < 1e-6:
            return [], {"unreachableChord": False, "blocked": False, "beyondEnergyRange": False}
        deviation = signed_angle(tangent, chord)
        # Hard physical bound before any table lookup: cloth friction only ever decelerates, so a
        # ball leaving at `speed` cannot cover more than v^2/(2a) no matter how it is spun. A miss
        # here is a genuine energy wall, not a hole in the sampling.
        ballistic = speed * speed / (2 * self.m.deceleration)
        if length > 1.02 * ballistic:
            return [], {"unreachableChord": True, "blocked": False, "beyondEnergyRange": True,
                        "deviationDegrees": deviation, "lengthMetres": length,
                        "maximumRangeMetres": ballistic,
                        "nearestMeasuredDeviationGapDegrees": None,
                        "measuredDeviationsAtThisSpeedAndLength": 0}
        samples = self.m.reach_query(speed, length, deviation)
        if not samples:
            window = self.m.reach_deviation_window(speed, length)
            gap = min((abs(k - deviation) for k in window), default=None)
            return [], {"unreachableChord": True, "blocked": False, "beyondEnergyRange": False,
                        "deviationDegrees": deviation, "lengthMetres": length,
                        "nearestMeasuredDeviationGapDegrees": gap,
                        "measuredDeviationsAtThisSpeedAndLength": len(window)}
        options, blocked = [], False
        # The real path bulges away from the chord, so the obstruction test is run with the
        # bulge added to the required margin. Samples are tried widest-bulge-last.
        for sample in sorted(samples, key=lambda s: s["bulge"]):
            margin = sample["bulge"]
            if not (self.clear_of_forbidden(start, target, margin)
                    and self.clear_of_balls(start, target, allowed_balls, margin)
                    and self.clear_of_pockets(start, target, allowed_pockets, margin)):
                blocked = True
                continue
            options.append({"direction": self._rotate(tangent, math.radians(sample["arrivalDirectionDegrees"])),
                            "length": length, "rails": 0, "legs": [(start, target)],
                            "chordDeviationDegrees": deviation, "arrivalSpeed": sample["arrivalSpeed"],
                            "bulgeMetres": sample["bulge"], "spinUsed": sample["spin"],
                            "probeImpactParameterInBallRadii": sample["impactParameterInBallRadii"],
                            "probePostContactSpeed": sample["postContactSpeed"]})
        return options, {"unreachableChord": False, "blocked": blocked,
                         "beyondEnergyRange": False}

    def travel_speed(self, speed, length, rails):
        v2 = speed * speed - 2 * self.m.deceleration * length
        if v2 <= 0:
            return 0.0
        v = math.sqrt(v2)
        return v * (self.m.rail_retention ** rails)

    def stats(self, index):
        """Per-segment failure bookkeeping for the current visiting order."""
        return self.current.setdefault(index, {"chordNotInReachSet": 0, "blocked": 0,
                                               "belowMinimumPotSpeed": 0, "cueStopped": 0,
                                               "noContact": 0, "noClearCueStart": 0,
                                               "noMeasurementAtThisSpeedAndLength": 0,
                                               "beyondEnergyRange": 0,
                                               "minDeviationGapDegrees": None})

    # -- depth-first chain search --------------------------------------------

    def solve_order(self, order, keep=4):
        """Extend the chain ball by ball; return closed solutions for this visiting order."""
        solutions = []
        self.current = {}
        self.reached = 0
        self.partials = {}
        first = order[0]
        for phi1 in self.phi_samples(first):
            ghost1, line1 = self.ghost(first, phi1)
            # Segment 1 is free: the cue start is chosen, so the impact parameter is a knob.
            for cut_degrees in self.cut_samples:
                cut = math.radians(cut_degrees)
                for side in (1, -1):
                    incoming = self._rotate(line1, side * cut)
                    b_over_r = 2 * math.sin(side * cut)
                    start, approach = self._cue_start(ghost1, incoming, order)
                    if start is None:
                        self.stats(0)["noClearCueStart"] += 1
                        continue
                    ball_speed = self.cue_speed_cap * self.m.strike_speed_gain
                    arrive = self.travel_speed(ball_speed, approach, 0)
                    target_speed = arrive * self.m.target_speed_ratio(b_over_r)
                    if target_speed < self.min_pot_speed:
                        self.stats(0)["belowMinimumPotSpeed"] += 1
                        continue
                    out_speed = arrive * self.m.cue_speed_ratio(b_over_r)
                    state = {"index": 1, "ghost": ghost1, "line": line1, "incoming": incoming,
                             "speed": out_speed, "phis": [phi1], "events": [
                                 {"kind": "ballBall", "ball": first, "impactParameterInBallRadii": b_over_r,
                                  "cutAngleDegrees": side * cut_degrees, "targetSpeed": target_speed,
                                  "lineOfCentresDegrees": math.degrees(angle_of(line1))},
                                 {"kind": "pocket", "ball": first, "pocket": BALL_POCKET[first]}],
                             "start": start, "aim": incoming, "cueSpeed": self.cue_speed_cap}
                    self._extend(order, state, solutions, keep)
                    if len(solutions) >= keep:
                        return solutions
                    if self.nodes > self.node_budget:
                        return solutions
        return solutions

    @staticmethod
    def _rotate(v, radians):
        c, s = math.cos(radians), math.sin(radians)
        return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)

    def _cue_start(self, ghost, incoming, order):
        """Back off from the ghost point until the cue start is a legal, unobstructed spot."""
        for reach in (1.2, 1.0, 0.8, 0.6, 0.45, 0.3, 0.2):
            start = sub(ghost, scale(incoming, reach))
            if abs(start[0]) > 1.27 - BALL_RADIUS - 0.002 or abs(start[1]) > 0.635 - BALL_RADIUS - 0.002:
                continue
            if not self.clear_of_forbidden(start, ghost):
                continue
            if not self.clear_of_balls(start, ghost, {order[0]}):
                continue
            if not self.clear_of_pockets(start, ghost, set()):
                continue
            if min(math.hypot(start[0] - p[0], start[1] - p[1]) for p in self.positions.values()) \
                    <= 2 * BALL_RADIUS + 0.002:
                continue
            return start, reach
        return None, 0.0

    def _extend(self, order, state, solutions, keep):
        self.nodes += 1
        if self.nodes > self.node_budget or len(solutions) >= keep:
            return
        index = state["index"]
        self.reached = max(self.reached, index)
        # Partial chains are what phase 2 gets to work with when nothing closes: u0 is fully
        # defined by the cue start, aim and speed, and the residual vector is defined for all six
        # balls whether or not the planner managed to chain them. A few per depth are kept, not
        # just the first, because phase 2 needs genuinely different starting shots.
        bucket = self.partials.setdefault(index, [])
        if len(bucket) < self.partials_per_depth:
            bucket.append({"ballsChained": index, "phis": state["phis"], "events": state["events"],
                           "cueStartXZ": list(state["start"]), "aimRadians": angle_of(state["aim"]),
                           "cueSpeed": state["cueSpeed"], "spinX": 0.0, "spinY": 0.0,
                           "closed": False})
        if index == len(order):
            final = self._finish(state)
            if final is None:
                self.stats(index)["cueStopped"] += 1
                return
            solutions.append({"order": list(order), "phis": state["phis"], "events": state["events"],
                              "cueStartXZ": list(state["start"]),
                              "aimRadians": angle_of(state["aim"]), "cueSpeed": state["cueSpeed"],
                              "spinX": 0.0, "spinY": 0.0,
                              "finalCueSpeed": final["speed"], "finalCuePathLength": final["length"]})
            return
        # Departure direction after the previous collision: tangent branch matching the arrival.
        tangent = (-state["line"][1], state["line"][0])
        if dot(tangent, state["incoming"]) < 0:
            tangent = scale(tangent, -1)
        ball = order[index]
        for phi in self.phi_samples(ball):
            ghost, line = self.ghost(ball, phi)
            allowed = {ball, order[index - 1]}
            allowed_pockets = {BALL_POCKET[order[index - 1]]}
            options, rejection = self.route_options(state["ghost"], ghost, allowed, allowed_pockets,
                                                    tangent, state["speed"])
            if rejection["unreachableChord"]:
                row = self.stats(index)
                row["chordNotInReachSet"] += 1
                gap = rejection["nearestMeasuredDeviationGapDegrees"]
                if rejection["beyondEnergyRange"]:
                    row["beyondEnergyRange"] += 1
                elif gap is None:
                    row["noMeasurementAtThisSpeedAndLength"] += 1
                elif row["minDeviationGapDegrees"] is None or gap < row["minDeviationGapDegrees"]:
                    row["minDeviationGapDegrees"] = gap
            if rejection["blocked"]:
                self.stats(index)["blocked"] += 1
            for option in options:
                arrive = option["arrivalSpeed"]
                if arrive <= 0.05:
                    self.stats(index)["cueStopped"] += 1
                    continue
                b_over_r = 2 * math.sin(math.radians(signed_angle(line, option["direction"])))
                if abs(b_over_r) >= 2.0:
                    self.stats(index)["noContact"] += 1
                    continue
                target_speed = arrive * self.m.target_speed_ratio(b_over_r)
                if target_speed < self.min_pot_speed:
                    self.stats(index)["belowMinimumPotSpeed"] += 1
                    continue
                events = list(state["events"])
                events.append({"kind": "ballBall", "ball": ball, "impactParameterInBallRadii": b_over_r,
                               "cutAngleDegrees": math.degrees(math.asin(min(1, abs(b_over_r) / 2))),
                               "targetSpeed": target_speed,
                               "chordDeviationFromTangentDegrees": option["chordDeviationDegrees"],
                               "segmentLengthMetres": option["length"],
                               "pathBulgeMetres": option["bulgeMetres"],
                               "probeSpinUsed": option["spinUsed"],
                               "lineOfCentresDegrees": math.degrees(angle_of(line))})
                events.append({"kind": "pocket", "ball": ball, "pocket": BALL_POCKET[ball]})
                self._extend(order, {"index": index + 1, "ghost": ghost, "line": line,
                                     "incoming": option["direction"],
                                     "speed": arrive * self.m.cue_speed_ratio(b_over_r),
                                     "phis": state["phis"] + [phi], "events": events,
                                     "start": state["start"], "aim": state["aim"],
                                     "cueSpeed": state["cueSpeed"]}, solutions, keep)
                if len(solutions) >= keep or self.nodes > self.node_budget:
                    return

    def _finish(self, state):
        """After the sixth collision the cue must run out without potting itself."""
        tangent = (-state["line"][1], state["line"][0])
        if dot(tangent, state["incoming"]) < 0:
            tangent = scale(tangent, -1)
        speed = state["speed"]
        length = speed * speed / (2 * self.m.deceleration)
        end = add(state["ghost"], scale(tangent, length))
        end = (max(-1.27 + BALL_RADIUS, min(1.27 - BALL_RADIUS, end[0])),
               max(-0.635 + BALL_RADIUS, min(0.635 - BALL_RADIUS, end[1])))
        if not self.clear_of_pockets(state["ghost"], end, set()):
            return None
        return {"speed": speed, "length": length}


# --------------------------------------------------------------------------- order enumeration

def distinct_partials(partials, limit):
    """Deepest partial chains, one per distinct initial vector.

    Most visiting orders share their deepest partial with many others (they differ only in balls
    the planner never reached), and phase 2 would otherwise spend its whole simulation budget
    refining copies of one shot.
    """
    seen, out = set(), []
    for partial in sorted(partials, key=lambda p: -p["ballsChained"]):
        key = (tuple(partial["order"][:partial["ballsChained"]]),
               round(partial["cueStartXZ"][0], 4), round(partial["cueStartXZ"][1], 4),
               round(partial["aimRadians"], 4), round(partial["cueSpeed"], 3))
        if key in seen:
            continue
        seen.add(key)
        out.append(partial)
        if len(out) >= limit:
            break
    return out


def canonical_orders():
    """One representative per equivalence class under the two mirror axes."""
    return canonical_orders_for(BALLS)


def canonical_orders_for(balls):
    """One representative per equivalence class, for any subset of the six balls.

    Spec v5 drops one ball, and a mirror only compresses the orders if it maps the *remaining*
    set onto itself. Dropping a corner ball (1/2/4/5) breaks both axes, so all 120 orders are
    distinct; dropping a side ball (3/8) leaves the long-axis mirror, so 60 classes remain.
    Applying the six-ball symmetries unconditionally would silently throw away real orders.
    """
    balls = list(balls)
    present = set(balls)
    mappings = [{b: b for b in balls}]
    for mirror in (MIRROR_X, MIRROR_Z, MIRROR_XZ):
        if all(mirror[b] in present for b in balls):
            mappings.append({b: mirror[b] for b in balls})
    seen, representatives = set(), []
    for order in itertools.permutations(balls):
        key = min(tuple(m[b] for b in order) for m in mappings)
        if key in seen:
            continue
        seen.add(key)
        representatives.append(key)
    return representatives


# --------------------------------------------------------------------------- entry point

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase0", required=True, help="phase-0 output root")
    parser.add_argument("--out", required=True, help="phase-1 output directory")
    parser.add_argument("--phi-step", type=float, default=3.0, help="acceptance sampling step, degrees")
    parser.add_argument("--cue-speed", type=float, default=8.0, help="cue tip speed cap, m/s")
    parser.add_argument("--node-budget", type=int, default=200000, help="chain nodes per visiting order")
    parser.add_argument("--keep", type=int, default=2, help="solutions kept per visiting order")
    parser.add_argument("--rungs", default="0,1,2,3,4")
    parser.add_argument("--cut-step", type=float, default=10.0,
                        help="first-segment cut-angle sampling step, degrees")
    parser.add_argument("--orders-from", default=None,
                        help="refine pass: earlier plan-rungN.json to take visiting orders from")
    parser.add_argument("--reach-angle-tolerance", type=float, default=4.0,
                        help="degrees a required chord may differ from a measured probe-E sample")
    parser.add_argument("--reach-speed-tolerance", type=float, default=0.25,
                        help="relative post-contact speed tolerance when matching probe-E samples")
    parser.add_argument("--reach-length-tolerance", type=float, default=0.05,
                        help="metres a required chord length may differ from a measured sample")
    parser.add_argument("--min-depth", type=int, default=6,
                        help="with --orders-from, keep orders whose chain reached this segment")
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)
    m = Measurements(args.phase0, speed_tolerance=args.reach_speed_tolerance,
                    length_tolerance=args.reach_length_tolerance,
                    angle_tolerance=args.reach_angle_tolerance)
    orders = canonical_orders()
    if args.orders_from:
        with open(args.orders_from, "r", encoding="utf-8") as handle:
            earlier = json.load(handle)
        orders = [tuple(row["order"]) for row in earlier["perOrder"]
                  if row["deepestSegmentReached"] >= args.min_depth]
    settings = {
        "spec": "SIX-POCKET-ONE-SHOT-20260917 problem restatement v4, phase 1",
        "phase0Root": os.path.abspath(args.phase0),
        "segmentReachModel": "probe E measured reach set (chord length, chord deviation from "
                             "tangent, arrival direction, arrival speed, path bulge)",
        "reachBuckets": m.reach_samples,
        "reachAngleToleranceDegrees": args.reach_angle_tolerance,
        "reachSpeedToleranceRelative": args.reach_speed_tolerance,
        "reachLengthToleranceMetres": args.reach_length_tolerance,
        "acceptanceSamplingStepDegrees": args.phi_step,
        "cushionsPerSegment": 0,
        "cushionsPerSegmentNote": "phase 1 plans direct segments only: probe E stops sampling at "
                                  "the cue's first rail, so no measured rail-crossing reach set "
                                  "exists yet. Rail-assisted segments are unimplemented, not ruled out.",
        "cueSpeedCapMetresPerSecond": args.cue_speed,
        "nodeBudgetPerOrder": args.node_budget,
        "visitingOrdersSearched": len(orders),
        "visitingOrderSource": args.orders_from or "all canonical classes under the two mirror axes",
        "firstSegmentCutStepDegrees": args.cut_step,
        "measuredStrikeSpeedGain": m.strike_speed_gain,
        "measuredRailRetention": m.rail_retention,
        "measuredRailMirrorDeviationSpreadDegrees": m.rail_deviation_spread,
        "measuredImmediateTangentDeviationSpreadDegrees": m.measured_tangent_spread,
        "measuredFreeRunDecelerationMetresPerSecondSquared": m.deceleration,
        "measuredFreeRunDecelerationP05P95": list(m.deceleration_range),
        "measuredFreeRunDecelerationSamples": m.deceleration_samples,
        "units": "metres; SceneKit XZ horizontal, Y up; portrait up=+X right=+Z",
    }
    with open(os.path.join(args.out, "experiment-settings.json"), "w", encoding="utf-8") as handle:
        json.dump(settings, handle, indent=2, sort_keys=True)

    summary = []
    for rung in [int(r) for r in args.rungs.split(",")]:
        planner = Planner(m, rung, args.phi_step, args.cue_speed, args.node_budget, args.cut_step)
        closed, per_order, partials = [], [], []
        # Per-segment aggregate over the orders that closed nothing: this is the rung's
        # infeasibility evidence — which segment breaks, by how much, and what limits it.
        aggregate = {}
        for order in orders:
            planner.nodes = 0
            solutions = planner.solve_order(order, keep=args.keep)
            per_order.append({"order": list(order), "solutions": len(solutions),
                              "nodesExplored": planner.nodes, "deepestSegmentReached": planner.reached + 1,
                              "segmentStats": {"segment%d" % (i + 1): v for i, v in sorted(planner.current.items())}})
            closed.extend(solutions)
            if solutions:
                continue
            for depth in sorted(planner.partials, reverse=True)[:2]:
                for row in planner.partials[depth]:
                    partial = dict(row)
                    partial["order"] = list(order)
                    partials.append(partial)
            for index, row in planner.current.items():
                key = "segment%d" % (index + 1)
                entry = aggregate.setdefault(key, {"ordersFailingHere": 0, "chordNotInReachSet": 0,
                                                   "blockedRejections": 0, "belowMinimumPotSpeed": 0,
                                                   "cueStopped": 0, "noContact": 0, "noClearCueStart": 0,
                                                   "noMeasurementAtThisSpeedAndLength": 0,
                                                   "beyondEnergyRange": 0,
                                                   "minDeviationGapDegrees": None})
                entry["ordersFailingHere"] += 1
                entry["chordNotInReachSet"] += row["chordNotInReachSet"]
                entry["noMeasurementAtThisSpeedAndLength"] += row["noMeasurementAtThisSpeedAndLength"]
                entry["beyondEnergyRange"] += row["beyondEnergyRange"]
                if row["minDeviationGapDegrees"] is not None:
                    current = entry["minDeviationGapDegrees"]
                    entry["minDeviationGapDegrees"] = row["minDeviationGapDegrees"] if current is None \
                        else min(current, row["minDeviationGapDegrees"])
                entry["blockedRejections"] += row["blocked"]
                entry["belowMinimumPotSpeed"] += row["belowMinimumPotSpeed"]
                entry["cueStopped"] += row["cueStopped"]
                entry["noContact"] += row["noContact"]
                entry["noClearCueStart"] += row["noClearCueStart"]
        failures = aggregate
        payload = {
            "rung": rung,
            "distanceMetres": m.fixture[rung]["distanceMetres"],
            "acceptanceIntervalsDegrees": {str(b): planner.acceptance[b] for b in BALLS},
            "closableOrders": closed,
            "deepestPartialChains": distinct_partials(partials, 40),
            "perOrder": per_order,
            "failuresBySegment": failures,
            "note": "closure here is idealised: tangent departure plus the measured bending "
                    "allowance, measured retention and deceleration. Only phase 2 on the real "
                    "engine can establish a pot.",
        }
        with open(os.path.join(args.out, "plan-rung%d.json" % rung), "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
        summary.append({"rung": rung, "distanceMetres": m.fixture[rung]["distanceMetres"],
                        "closableOrders": len(closed),
                        "deepestSegmentReached": max(p["deepestSegmentReached"] for p in per_order),
                        "acceptanceHalfWidthsDegrees": {
                            str(b): (planner.acceptance[b][0][1] - planner.acceptance[b][0][0]) / 2
                            if planner.acceptance[b] else 0 for b in BALLS},
                        "failureSegments": sorted(failures)})
        print("rung %d d=%.6f closable=%d" % (rung, m.fixture[rung]["distanceMetres"], len(closed)))
    with open(os.path.join(args.out, "plan-summary.json"), "w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2, sort_keys=True)


if __name__ == "__main__":
    main()

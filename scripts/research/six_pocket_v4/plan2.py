#!/usr/bin/env python3
"""v4 round-2 phase-1 planner for "one shot, six pocket-side balls".

Why a second planner instead of a patch to `plan.py`:

* FL-079. Round 1 pruned every segment with `length > v²/(2a)`, a = 1.962 m/s². That number is
  µ_s·g: it only describes the sliding phase, which the round-1 probes never left (all samples were
  under a metre from the strike or the collision). Round-2 probe F2 measures the phases separately —
  sliding 1.938 m/s² until the slide→roll transition at 0.714·v, then rolling 0.098 m/s² — so the
  reachability bound is now two-phase and the "energy wall" that killed 30 % of round-1 segments
  from the third ball on is gone.
* Round 1 could only plan 0-rail segments and had no notion of one spin serving all six segments.
  Here the cue's physical state (speed, rolling ratio, english) is carried from collision to
  collision through measured maps, and a segment may use 0, 1 or 2 straight rails.

Model, all four maps measured by `SixPocketV4Round2ProbeTests`:

    collision-map   (incoming speed, rolling ratio, english, impact parameter b)
                    -> cue departure (speed, angle off the stun tangent, rolling ratio, english)
                       and the target ball's launch speed and throw
    free-arc        (speed, rolling ratio, english, curl, chord length)
                    -> chord deviation, arrival direction, arrival speed, arrival spin, bulge
    rail-map        (rail index, incoming speed, rolling ratio, english, incidence)
                    -> retention, deviation from mirror, outgoing spin
    long-free-run   the two-phase deceleration used for the cheap reachability bound

Search. Once the cue's state entering a collision and the impact parameter are fixed, everything
downstream is determined, so the chain is not a free-choice tree: the only freedom per segment is
b_k inside the ball's clean acceptance window. The arrival *direction* at a ball is likewise not
free — the line of centres has to point into that ball's own pocket, so the direction follows from
b and the pot direction. That makes the node space small enough to enumerate: a node is
(ball, cue state), edges are (collision, arc, optional rails) transitions, and every
visiting order is a reachability question on the same graph. Transitions are shared by all orders
that contain the same ordered pair, so they are computed once per pair per rung.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from plan import (  # noqa: E402  - same directory, shared constants and geometry
    BALL_RADIUS, BALLS, BALL_POCKET, POCKETS, Measurements, add, angle_of, canonical_orders_for,
    dot, from_angle, norm, point_segment_distance, scale, segment_segment_distance, signed_angle,
    sub, unit,
)

GRAVITY = 9.81


def rotate(v, radians):
    c, s = math.cos(radians), math.sin(radians)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)


# --------------------------------------------------------------------------- round-2 phase 0


class Round2Measurements:
    """The four round-2 maps, each indexed on its own seed grid.

    The three tables were probed on different grids (the collision map has no 0.3 m/s seed, the rail
    map steps speed 1.8/2.5/3.5 where the arc table steps 1.6/2.2/3.0/4.0, and the arc table carries
    two extra english levels). A single shared binning therefore leaves whole buckets empty and the
    planner reads that as "not reachable" — the first version of this file lost every rail route
    that way. So the cue state is carried as continuous floats and snapped to each table's own seed
    grid at query time, with the snap distance available to the caller.
    """

    LENGTH_BUCKET = 0.05
    B_BUCKET = 0.05

    def __init__(self, root: str):
        self.root = root
        self.long_run = self._read("longrun", "long-free-run", "long-free-run-summary.json")
        self.arc = self._read("arc", "free-arc", "free-arc.json")
        self.collision = self._read("collision2", "collision-map", "collision-map.json")
        self.rail = self._read("rail", "rail-map", "rail-map.json")
        self.arc_settings = self._read("arc", "free-arc", "experiment-settings.json")
        self.sliding_deceleration = self.long_run["slidingDecelerationMedian"]
        self.rolling_deceleration = self.long_run["rollingDecelerationMedian"]
        self.transition_ratio = self.long_run["transitionSpeedRatioMedian"]
        self.max_spin = self.arc_settings["maxAchievableSpinRadPerSec"]
        self._index_arc()
        self._index_collision()
        self._index_rail()

    def _read(self, *parts):
        with open(os.path.join(self.root, *parts), "r", encoding="utf-8") as handle:
            return json.load(handle)

    # -- state snapping -------------------------------------------------------

    @staticmethod
    def _nearest(value, grid):
        return min(grid, key=lambda g: abs(g - value))

    def snap(self, grids, speed, roll, english):
        """Nearest seed cell of one table's own grid, plus the snap distances."""
        speeds, rolls, englishes = grids
        s = self._nearest(speed, speeds)
        r = self._nearest(roll, rolls)
        e = self._nearest(english, englishes)
        return (s, r, e), (abs(s - speed), abs(r - roll), abs(e - english) / self.max_spin)

    # -- reachability bound (FL-079 correction) -------------------------------

    def max_range(self, speed):
        """Two-phase upper bound on how far a ball leaving at `speed` can still travel.

        Sliding phase down to the transition speed at the measured µ_s·g, then rolling at the
        measured µ_r·g. Round 1 used the sliding coefficient for the whole run, which understated
        the range by 2.3x on the configurations that stopped on the table and by an order of
        magnitude at low speed (FL-079).
        """
        v_roll = self.transition_ratio * speed
        sliding = max(0.0, (speed * speed - v_roll * v_roll) / (2 * self.sliding_deceleration))
        rolling = v_roll * v_roll / (2 * self.rolling_deceleration)
        return sliding + rolling

    # -- free arcs ------------------------------------------------------------

    def _index_arc(self):
        c = {name: i for i, name in enumerate(self.arc["columns"])}
        self.arc_index = {}
        speeds, rolls, englishes = set(), set(), set()
        for row in self.arc["rows"]:
            seed = (row[c["seedSpeed"]], row[c["seedRollRatio"]], row[c["seedEnglish"]])
            speeds.add(seed[0])
            rolls.add(seed[1])
            englishes.add(seed[2])
            key = seed + (int(row[c["chordLengthMetres"]] / self.LENGTH_BUCKET),)
            sample = (row[c["chordLengthMetres"]], row[c["chordDeviationDegrees"]],
                      row[c["arrivalDirectionDegrees"]], row[c["arrivalSpeed"]],
                      row[c["arrivalRollRatio"]], row[c["arrivalEnglish"]],
                      row[c["bulgeMetres"]], row[c["seedCurl"]])
            bucket = self.arc_index.setdefault(key, [])
            # Curl is not a knob the chain sets deliberately, so keep the sample closest to zero
            # curl per bucket, plus the one that bends most (what a turning segment needs).
            if len(bucket) < 2:
                bucket.append(sample)
            else:
                if abs(sample[7]) < abs(bucket[0][7]):
                    bucket[0] = sample
                if abs(sample[1]) > abs(bucket[1][1]):
                    bucket[1] = sample
        self.arc_grid = (sorted(speeds), sorted(rolls), sorted(englishes))
        self.arc_rows = len(self.arc["rows"])

    def arc_query(self, speed, roll, english, length, length_tolerance=0.06):
        """Measured arcs of roughly this chord length, from the nearest measured launch state."""
        seed, _ = self.snap(self.arc_grid, speed, roll, english)
        tol = max(length_tolerance, 0.04 * length)
        lo = int((length - tol) / self.LENGTH_BUCKET)
        hi = int((length + tol) / self.LENGTH_BUCKET)
        out = []
        for b in range(lo, hi + 1):
            for sample in self.arc_index.get(seed + (b,), ()):
                if abs(sample[0] - length) <= tol:
                    out.append(sample)
        return out

    # -- collisions -----------------------------------------------------------

    def _index_collision(self):
        c = {name: i for i, name in enumerate(self.collision["columns"])}
        self.collision_index = {}
        speeds, rolls, englishes = set(), set(), set()
        settings = self._read("collision2", "collision-map", "experiment-settings.json")
        for value in settings["seedSpeeds"]:
            speeds.add(value)
        for value in settings["seedRollRatios"]:
            rolls.add(value)
        for value in settings["seedEnglishRadPerSec"]:
            englishes.add(value)
        self.collision_grid = (sorted(speeds), sorted(rolls), sorted(englishes))
        for row in self.collision["rows"]:
            # Rows are labelled by the measured pre-contact state, which drifts from the seed over
            # the approach, so each row is filed under the seed cell it is closest to.
            seed, _ = self.snap(self.collision_grid, row[c["incomingSpeed"]],
                                row[c["incomingRollRatio"]], row[c["incomingEnglish"]])
            key = seed + (int(round(row[c["impactParameterInBallRadii"]] / self.B_BUCKET)),)
            sample = (row[c["impactParameterInBallRadii"]], row[c["cueOutSpeed"]],
                      row[c["cueOutDirectionFromTangentDegrees"]], row[c["cueOutRollRatio"]],
                      row[c["cueOutEnglish"]], row[c["targetOutSpeed"]],
                      row[c["targetOutDirectionFromCentreLineDegrees"]])
            self.collision_index.setdefault(key, []).append(sample)
        self.collision_rows = len(self.collision["rows"])

    def collision_query(self, speed, roll, english, b):
        seed, _ = self.snap(self.collision_grid, speed, roll, english)
        return self.collision_index.get(seed + (int(round(b / self.B_BUCKET)),), ())

    # -- rails ----------------------------------------------------------------

    def _index_rail(self):
        c = {name: i for i, name in enumerate(self.rail["columns"])}
        settings = self._read("rail", "rail-map", "experiment-settings.json")
        self.rail_grid = (sorted(settings["seedSpeeds"]), sorted(settings["seedRollRatios"]),
                          sorted(settings["seedEnglishRadPerSec"]))
        self.rail_index = {}
        for row in self.rail["rows"]:
            seed, _ = self.snap(self.rail_grid, row[c["incomingSpeed"]],
                                row[c["incomingRollRatio"]], row[c["incomingEnglish"]])
            key = (int(row[c["railIndex"]]),) + seed + (int(row[c["incidenceFromNormalDegrees"]] / 10),)
            sample = (row[c["speedRetention"]], row[c["deviationFromMirrorDegrees"]],
                      row[c["outRollRatio"]], row[c["outEnglish"]])
            self.rail_index.setdefault(key, []).append(sample)
        self.rail_rows = len(self.rail["rows"])
        retention = sorted(row[c["speedRetention"]] for row in self.rail["rows"])
        deviation = sorted(row[c["deviationFromMirrorDegrees"]] for row in self.rail["rows"])
        self.rail_retention_median = retention[len(retention) // 2]
        self.rail_deviation_span = (deviation[int(0.05 * (len(deviation) - 1))],
                                    deviation[int(0.95 * (len(deviation) - 1))])

    def rail_query(self, rail_index, speed, roll, english, incidence):
        seed, _ = self.snap(self.rail_grid, speed, roll, english)
        bucket = int(incidence / 10)
        found = self.rail_index.get((rail_index,) + seed + (bucket,), ())
        if found:
            return found
        # The six straight rails are the same wall up to a rigid motion, so a missing (rail, state)
        # cell falls back to the same state measured on another rail, then to a neighbouring
        # incidence bucket, before giving up.
        for other in (0, 1, 2, 3, 4, 5):
            found = self.rail_index.get((other,) + seed + (bucket,), ())
            if found:
                return found
        for delta in (-1, 1):
            for other in (0, 1, 2, 3, 4, 5):
                found = self.rail_index.get((other,) + seed + (bucket + delta,), ())
                if found:
                    return found
        return ()


# --------------------------------------------------------------------------- planner


class ChainGraph:
    """Nodes are (ball, cue state); edges are measured chain segments."""

    def __init__(self, m: Measurements, r2: Round2Measurements, rung: int, args):
        self.m = m
        self.r2 = r2
        self.rung = rung
        self.args = args
        # Spec v5: the omitted ball is off the table entirely, so it is neither a chain target nor
        # an obstacle. Its pocket stays in `POCKETS` and is never added to `allowed_pockets`, so
        # the emptied hole is treated as cue-forbidden exactly like any unvisited pocket.
        self.balls = [b for b in BALLS if b != args.omit]
        self.omit = args.omit
        self.positions = {b: p for b, p in m.ball_positions(rung).items() if b != args.omit}
        self.acceptance = {}
        self.base_direction = {}
        for ball in self.balls:
            runs, base, _ = m.acceptance(rung, ball)
            self.acceptance[ball] = runs
            self.base_direction[ball] = base
        self.min_pot_speed = {}
        for row in m.pot_maps[rung]["balls"]:
            speeds = [s["speed"] for s in row["cleanAcceptanceBySpeed"] if s[m.pot_window_key]]
            self.min_pot_speed[row["ball"]] = min(speeds) if speeds else float("inf")
        self.straight_rails = m.straight_rails
        self.stats = {}
        self.b_samples = self._b_samples()

    # -- acceptance -> impact parameter --------------------------------------

    def _b_samples(self):
        """Signed impact parameters to try at each ball, and nothing else.

        Round 1 enumerated the pot window φ and the impact parameter independently, which is both
        wasteful and wrong: once the cue arrives along a direction w, requiring the target to leave
        along the line of centres fixes φ from b, because the cut angle satisfies sin θ = b/2. So
        the only per-ball knob is b, and φ is solved for (`solve_contact`). The pot map's window is
        then a constraint on the solved φ, not a search dimension.
        """
        return {ball: self.b_grid() for ball in self.balls}

    def b_grid(self):
        step = self.args.b_step
        n = int(math.floor(1.9 / step))
        return [round(i * step, 4) for i in range(-n, n + 1)]

    def phi_in_window(self, ball, phi):
        return self.window_excess(ball, phi) <= 0

    def window_excess(self, ball, phi):
        """Degrees by which a line-of-centres angle misses the ball's clean pot window (0 = inside).

        Reporting this, rather than a bare reject, is what turns "not closable" into "this segment
        was asked to arrive N degrees outside the measured clean window".
        """
        best = None
        for lo, hi in self.acceptance[ball]:
            if lo - 1e-9 <= phi <= hi + 1e-9:
                return 0.0
            gap = lo - phi if phi < lo else phi - hi
            best = gap if best is None else min(best, gap)
        return best if best is not None else 180.0

    def solve_contact(self, source, ball, b, iterations=3):
        """Contact geometry at `ball` for a cue coming from `source` with impact parameter `b`.

        Fixed point on the approach direction: the contact point depends on the direction, and the
        direction depends on the contact point. Three passes settle it to well under a degree for
        the distances in play here.
        """
        centre = self.positions[ball]
        half = max(-1.0, min(1.0, b / 2.0))
        theta = math.asin(half)
        travel = unit(sub(centre, source))
        contact = None
        for _ in range(iterations):
            line = rotate(travel, theta)
            contact = sub(centre, scale(line, 2 * BALL_RADIUS))
            new_travel = unit(sub(contact, source))
            if norm(sub(new_travel, travel)) < 1e-6:
                travel = new_travel
                break
            travel = new_travel
        line = rotate(travel, theta)
        contact = sub(centre, scale(line, 2 * BALL_RADIUS))
        phi = math.degrees(angle_of(line) - self.base_direction[ball])
        while phi > 180:
            phi -= 360
        while phi < -180:
            phi += 360
        return contact, travel, line, phi

    def contact_geometry(self, ball, phi_degrees, b):
        """Cue-centre point at contact and the cue's travel direction there.

        `phi` is the line-of-centres angle off the pocket direction; `b` is the signed impact
        parameter in ball radii (left-positive relative to the travel direction).
        """
        line = from_angle(self.base_direction[ball] + math.radians(phi_degrees))
        centre = self.positions[ball]
        contact = sub(centre, scale(line, 2 * BALL_RADIUS))
        # sin θ = b/2 with θ the angle between travel direction and the line of centres.
        half = max(-1.0, min(1.0, b / 2.0))
        theta = math.asin(half)
        travel = rotate(line, -theta)
        return contact, travel, line

    # -- clearance ------------------------------------------------------------

    def on_table(self, point):
        """Whether a cue *centre* may sit here: inside every straight rail by a full radius.

        The first version used hand-written bounds (|x| < 1.24, |z| < 0.60). They happen to be
        inside the true limits (1.241425 / 0.606425 once the cushion line is pulled in by a
        radius), so they lost a strip of legal opening positions rather than admitting illegal
        ones. Deriving the bound from the measured cushion geometry removes the guess.
        """
        for rail in self.straight_rails:
            n = rail["normal"]
            anchor = add(rail["start"], scale(n, BALL_RADIUS))
            if dot(sub(point, anchor), n) < 0:
                return False
        return True

    def clear_of_forbidden(self, a, b, margin=0.0):
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

    def clear_leg(self, a, b, allowed_balls, allowed_pockets, margin):
        return (self.clear_of_forbidden(a, b, margin)
                and self.clear_of_balls(a, b, allowed_balls, margin)
                and self.clear_of_pockets(a, b, allowed_pockets, margin))

    # -- rail routing ---------------------------------------------------------

    def mirror_point(self, point, rail):
        """Reflect a point across a straight rail's cue-centre line (rail offset by one radius)."""
        n = rail["normal"]
        # Rail line, pulled in by a ball radius: that is where the cue centre turns.
        a = add(rail["start"], scale(n, BALL_RADIUS))
        d = dot(sub(point, a), n)
        return sub(point, scale(n, 2 * d)), d

    def rail_paths(self, start, target, max_rails):
        """Candidate cue-centre polylines from `start` to `target` using straight rails.

        Mirror construction: reflect the target across one (or two) rails, aim at the image, and
        keep the intersection points that actually land on the rail. Retention and the deviation
        from the mirror direction come from the measured rail map, so the mirror is only used to
        generate the candidate geometry; the check that the engine agrees is phase 2's job.
        """
        paths = [(0, [start, target], [])]
        if max_rails < 1:
            return paths
        for rail in self.straight_rails:
            image, d_target = self.mirror_point(target, rail)
            _, d_start = self.mirror_point(start, rail)
            if d_start <= 0 or d_target <= 0:
                continue  # start or target is behind the rail line
            hit = self._rail_hit(start, image, rail)
            if hit is None:
                continue
            paths.append((1, [start, hit, target], [rail["index"]]))
            if max_rails < 2:
                continue
            for second in self.straight_rails:
                if second["index"] == rail["index"]:
                    continue
                image2, d2 = self.mirror_point(image, second)
                if d2 <= 0:
                    continue
                hit1 = self._rail_hit(start, image2, rail)
                if hit1 is None:
                    continue
                hit2 = self._rail_hit(hit1, image, second)
                if hit2 is None:
                    continue
                paths.append((2, [start, hit1, hit2, target], [rail["index"], second["index"]]))
        return paths

    def _rail_hit(self, a, b, rail):
        """Where segment a→b crosses the rail's cue-centre line, if it does so on the rail."""
        n = rail["normal"]
        anchor = add(rail["start"], scale(n, BALL_RADIUS))
        da = dot(sub(a, anchor), n)
        db = dot(sub(b, anchor), n)
        if (da > 0) == (db > 0) or abs(da - db) < 1e-12:
            return None
        t = da / (da - db)
        point = add(a, scale(sub(b, a), t))
        # Must land between the rail's endpoints (pulled in a radius at each end so the cue is not
        # actually touching a jaw line at the corner).
        tangent = unit(sub(rail["end"], rail["start"]))
        s = dot(sub(point, rail["start"]), tangent)
        if s < BALL_RADIUS or s > norm(sub(rail["end"], rail["start"])) - BALL_RADIUS:
            return None
        return point

    # -- one segment ----------------------------------------------------------

    def transitions(self, ball, contact, travel, line, b, state, next_ball, allowed_balls,
                    allowed_pockets):
        """All ways to leave `ball` (hit with `b` in state `state`) and arrive at `next_ball`.

        `state` is the continuous cue state (speed, rolling ratio, english) carried from the
        previous collision; each measured table snaps it to its own seed grid.
        """
        stats = self.stats.setdefault("pair_%d_%d" % (ball, next_ball),
                                      {"noCollisionSample": 0, "targetTooSlow": 0,
                                       "cueStopped": 0, "beyondTwoPhaseRange": 0,
                                       "noArcSample": 0, "arcAngleMismatch": 0, "blocked": 0,
                                       "outsidePotWindow": 0, "accepted": 0,
                                       "arrivalAngleMismatch": 0,
                                       "minArcAngleGapDegrees": None,
                                       "minArrivalAngleGapDegrees": None,
                                       "minPotWindowExcessDegrees": None,
                                       "minRailDeviationGapDegrees": None})
        speed_in, roll_in, english_in = state
        samples = self.r2.collision_query(speed_in, roll_in, english_in, b)
        if not samples:
            stats["noCollisionSample"] += 1
            return []
        # Stun tangent: perpendicular to the line of centres, on the cue's side of it.
        raw = (-line[1], line[0])
        tangent = raw if dot(raw, travel) >= 0 else (-raw[0], -raw[1])
        out = []
        for (_, cue_speed, cue_angle, cue_roll, cue_english, target_speed, _) in samples[:2]:
            if target_speed < self.min_pot_speed[ball]:
                stats["targetTooSlow"] += 1
                continue
            if cue_speed < 1e-3:
                stats["cueStopped"] += 1
                continue
            launch = rotate(tangent, math.radians(cue_angle))
            # `--unlimited-range` answers "is the 8 m/s cap what stops the chain?" directly: with
            # the reachability bound removed the cue may travel any distance, which is strictly
            # more permissive than any speed increase could ever be. If the depth does not move,
            # raising the cue speed cannot help, and the spec forbids raising it (clause 2).
            reach = float("inf") if self.args.unlimited_range else self.r2.max_range(cue_speed)
            for next_b in self.b_samples[next_ball]:
                next_contact, next_travel, _, next_phi = self.solve_contact(contact, next_ball, next_b)
                excess = self.window_excess(next_ball, next_phi)
                if excess > 0:
                    stats["outsidePotWindow"] += 1
                    if (stats["minPotWindowExcessDegrees"] is None
                            or excess < stats["minPotWindowExcessDegrees"]):
                        stats["minPotWindowExcessDegrees"] = excess
                    # A straight run is outside the window, but a rail route arrives from a
                    # different side, so the rail candidates are still worth generating.
                    if self.args.max_rails < 1:
                        continue
                straight = norm(sub(next_contact, contact))
                if straight > reach:
                    stats["beyondTwoPhaseRange"] += 1
                    continue
                for rails, points, rail_indices in self.rail_paths(
                        contact, next_contact, self.args.max_rails):
                    if rails:
                        # With rails the last leg sets the arrival direction, so the contact point
                        # has to be re-solved from the final turn instead of from the collision.
                        next_contact, next_travel, _, next_phi = self.solve_contact(
                            points[-2], next_ball, next_b)
                        excess = self.window_excess(next_ball, next_phi)
                        if excess > 0:
                            stats["outsidePotWindow"] += 1
                            if (stats["minPotWindowExcessDegrees"] is None
                                    or excess < stats["minPotWindowExcessDegrees"]):
                                stats["minPotWindowExcessDegrees"] = excess
                            continue
                        points = points[:-1] + [next_contact]
                    elif excess > 0:
                        continue
                    total = sum(norm(sub(points[i + 1], points[i])) for i in range(len(points) - 1))
                    if total > reach:
                        stats["beyondTwoPhaseRange"] += 1
                        continue
                    result = self._follow(points, rail_indices, launch, cue_speed,
                                          cue_roll, cue_english, next_travel, allowed_balls,
                                          allowed_pockets, stats)
                    if result is None:
                        continue
                    arrival_state, bulges, angle_error = result
                    arrival_speed = arrival_state[0]
                    if arrival_speed < self.min_pot_speed[next_ball]:
                        stats["targetTooSlow"] += 1
                        continue
                    stats["accepted"] += 1
                    out.append({
                        "ball": ball, "b": b, "nextBall": next_ball,
                        "nextPhi": next_phi, "nextB": next_b,
                        "contactXZ": contact, "nextContactXZ": next_contact,
                        "nextTravel": next_travel,
                        "rails": rails, "railIndices": rail_indices,
                        "points": points, "lengthMetres": total,
                        "departureSpeed": cue_speed, "arrivalSpeed": arrival_speed,
                        "arrivalState": arrival_state,
                        "arrivalDirectionErrorDegrees": angle_error,
                        "bulgeMetres": max(bulges) if bulges else 0.0,
                        "state": state,
                        "incomingSpeed": speed_in, "incomingRoll": roll_in,
                        "incomingEnglish": english_in,
                        "targetLaunchSpeed": target_speed,
                    })
        return out

    def _follow(self, points, rail_indices, launch_direction, speed, roll, english,
                required_direction, allowed_balls, allowed_pockets, stats):
        """Walk a candidate polyline leg by leg through the measured arc and rail maps."""
        direction = launch_direction
        current_speed, current_roll, current_english = speed, roll, english
        bulges = []
        for leg in range(len(points) - 1):
            a, b = points[leg], points[leg + 1]
            length = norm(sub(b, a))
            if length < 1e-6:
                continue
            chord = unit(sub(b, a))
            wanted = signed_angle(direction, chord)
            arcs = self.r2.arc_query(current_speed, current_roll, current_english, length)
            if not arcs:
                stats["noArcSample"] += 1
                return None
            best = None
            for sample in arcs:
                gap = abs(sample[1] - wanted)
                if best is None or gap < best[0]:
                    best = (gap, sample)
            gap, sample = best
            if stats["minArcAngleGapDegrees"] is None or gap < stats["minArcAngleGapDegrees"]:
                stats["minArcAngleGapDegrees"] = gap
            if gap > self.args.arc_angle_tolerance:
                stats["arcAngleMismatch"] += 1
                return None
            _, _, arrival_angle, arrival_speed, arrival_roll, arrival_english, bulge, _ = sample
            if not self.clear_leg(a, b, allowed_balls, allowed_pockets, bulge):
                stats["blocked"] += 1
                return None
            bulges.append(bulge)
            direction = rotate(direction, math.radians(arrival_angle))
            current_speed = arrival_speed
            if current_speed < 1e-3:
                stats["cueStopped"] += 1
                return None
            if leg < len(points) - 2:
                rail = next(r for r in self.straight_rails if r["index"] == rail_indices[leg])
                n = rail["normal"]
                incidence = abs(signed_angle((-n[0], -n[1]), direction))
                incidence = min(89.0, incidence)
                rail_samples = self.r2.rail_query(rail["index"], current_speed, arrival_roll,
                                                  arrival_english, incidence)
                if not rail_samples:
                    stats["noArcSample"] += 1
                    return None
                d = dot(direction, n)
                mirror = sub(direction, scale(n, 2 * d))
                # The remaining polyline fixes the direction the cue must leave the rail on, so the
                # measured deviation is selected to match it (english is what produces the spread)
                # and the residual is recorded rather than assumed away.
                needed = signed_angle(mirror, unit(sub(points[leg + 2], b)))
                retention, deviation, out_roll, out_english = min(
                    rail_samples, key=lambda s: abs(s[1] - needed))
                gap = abs(deviation - needed)
                if (stats["minRailDeviationGapDegrees"] is None
                        or gap < stats["minRailDeviationGapDegrees"]):
                    stats["minRailDeviationGapDegrees"] = gap
                if gap > self.args.rail_angle_tolerance:
                    stats["arcAngleMismatch"] += 1
                    return None
                direction = rotate(mirror, math.radians(deviation))
                current_speed *= retention
                arrival_roll, arrival_english = out_roll, out_english
            current_roll, current_english = arrival_roll, arrival_english
        # The cue must arrive travelling along the direction the next contact needs.
        angle_error = abs(signed_angle(direction, required_direction))
        if (stats["minArrivalAngleGapDegrees"] is None
                or angle_error < stats["minArrivalAngleGapDegrees"]):
            stats["minArrivalAngleGapDegrees"] = angle_error
        if angle_error > self.args.arrival_angle_tolerance:
            stats["arrivalAngleMismatch"] += 1
            return None
        return (current_speed, current_roll, current_english), bulges, angle_error


# --------------------------------------------------------------------------- pair relaxation


def rail_first_openings(graph: "ChainGraph", args, first, openings, seen_open):
    """Openings where the cue starts anywhere legal and takes a rail *before* the first ball.

    Round 2 §8 item 3: every opening so far was a straight back-off from the first contact point,
    so the first segment could never arrive from a direction that only a cushion can produce.
    Here the cue start is a free grid point on the table, the route to the first contact uses
    1–`--opening-rails` straight rails, and the polyline is walked through the same measured arc
    and rail maps as any mid-chain segment (`_follow`), so nothing about this opening is assumed.
    """
    stats = graph.stats.setdefault("opening_rail_%d" % first,
                                   {"noCollisionSample": 0, "targetTooSlow": 0, "cueStopped": 0,
                                    "beyondTwoPhaseRange": 0, "noArcSample": 0,
                                    "arcAngleMismatch": 0, "blocked": 0, "outsidePotWindow": 0,
                                    "accepted": 0, "arrivalAngleMismatch": 0,
                                    "minArcAngleGapDegrees": None, "minArrivalAngleGapDegrees": None,
                                    "minPotWindowExcessDegrees": None,
                                    "minRailDeviationGapDegrees": None})
    step = args.opening_start_step
    starts = []
    x = -1.24
    while x <= 1.24 + 1e-9:
        z = -0.60
        while z <= 0.60 + 1e-9:
            point = (round(x, 4), round(z, 4))
            if graph.on_table(point):
                starts.append(point)
            z += step
        x += step
    seeds = openings[::max(1, args.opening_seed_stride)]
    out = []
    heading_steps = int(round(360.0 / args.opening_direction_step))
    centre = graph.positions[first]
    for heading_index in range(heading_steps):
        heading = from_angle(math.radians(heading_index * args.opening_direction_step))
        source = sub(centre, scale(heading, args.opening_backoff + 2 * BALL_RADIUS))
        for b in graph.b_samples[first]:
            contact, travel, line, phi = graph.solve_contact(source, first, b)
            excess = graph.window_excess(first, phi)
            if excess > 0:
                stats["outsidePotWindow"] += 1
                if (stats["minPotWindowExcessDegrees"] is None
                        or excess < stats["minPotWindowExcessDegrees"]):
                    stats["minPotWindowExcessDegrees"] = excess
                continue
            for start in starts:
                for rails, points, rail_indices in graph.rail_paths(start, contact,
                                                                    args.opening_rails):
                    if rails < 1:
                        continue  # straight openings are already enumerated by the caller
                    # The last leg fixes the approach, so re-solve the contact from the last turn.
                    solved, travel_r, line_r, phi_r = graph.solve_contact(points[-2], first, b)
                    excess = graph.window_excess(first, phi_r)
                    if excess > 0:
                        stats["outsidePotWindow"] += 1
                        if (stats["minPotWindowExcessDegrees"] is None
                                or excess < stats["minPotWindowExcessDegrees"]):
                            stats["minPotWindowExcessDegrees"] = excess
                        continue
                    points = points[:-1] + [solved]
                    total = sum(norm(sub(points[i + 1], points[i])) for i in range(len(points) - 1))
                    launch = unit(sub(points[1], points[0]))
                    for seed, _ in seeds:
                        if not args.unlimited_range and total > graph.r2.max_range(seed[0]):
                            stats["beyondTwoPhaseRange"] += 1
                            continue
                        result = graph._follow(points, rail_indices, launch, seed[0], seed[1],
                                               seed[2], travel_r, {first}, set(), stats)
                        if result is None:
                            continue
                        arrival_state, _, _ = result
                        if arrival_state[0] < graph.min_pot_speed[first]:
                            stats["targetTooSlow"] += 1
                            continue
                        node = (round(arrival_state[0], 2), round(arrival_state[1], 2),
                                round(arrival_state[2], 1), round(phi_r, 1), b)
                        if node in seen_open:
                            continue
                        seen_open.add(node)
                        stats["accepted"] += 1
                        out.append({"ball": first, "state": arrival_state, "b": b, "phi": phi_r,
                                    "contact": solved, "travel": travel_r, "line": line_r,
                                    "start": start, "openingRails": rail_indices,
                                    "openingPoints": points,
                                    "seedSpeed": seed[0], "seedRoll": seed[1],
                                    "seedEnglish": seed[2]})
    return out


def pair_matrix(graph: "ChainGraph", r2: Round2Measurements, args, log):
    """Feasibility of every ordered pair, over *all* incoming cue states.

    This is a relaxation: the incoming state at the first ball of the pair is allowed to be
    anything the collision map covers, instead of whatever the previous segment would really
    deliver. So a pair marked infeasible here is infeasible for every chain, and any visiting order
    that contains such a pair cannot close — that is a proof of non-closability at the resolution of
    these grids, not a search that gave up. A pair marked feasible is only *possibly* usable.
    """
    speeds = r2.collision_grid[0][::args.pair_speed_stride]
    rolls = r2.collision_grid[1][::args.pair_roll_stride]
    englishes = r2.collision_grid[2]
    matrix = {}
    for first in graph.balls:
        centre = graph.positions[first]
        for second in graph.balls:
            if first == second:
                continue
            started = time.time()
            graph.stats.pop("pair_%d_%d" % (first, second), None)
            accepted = []
            # Feasibility is a yes/no question, so the sweep stops as soon as it has enough
            # witnesses: an easy pair such as 3->2 accepts tens of thousands of edges and
            # collecting them all dominated the run time.
            cap = args.pair_witness_cap
            steps = int(round(360.0 / args.opening_direction_step))
            for step in range(steps):
                if len(accepted) >= cap:
                    break
                heading = from_angle(math.radians(step * args.opening_direction_step))
                source = sub(centre, scale(heading, args.opening_backoff + 2 * BALL_RADIUS))
                for b in graph.b_samples[first]:
                    if len(accepted) >= cap:
                        break
                    contact, travel, line, phi = graph.solve_contact(source, first, b)
                    if not graph.phi_in_window(first, phi):
                        continue
                    start = sub(contact, scale(travel, args.opening_backoff))
                    if not graph.on_table(start):
                        continue
                    for speed in speeds:
                        if len(accepted) >= cap:
                            break
                        for roll in rolls:
                            for english in englishes:
                                edges = graph.transitions(
                                    first, contact, travel, line, b, (speed, roll, english),
                                    second, {first, second}, {BALL_POCKET[first]})
                                for edge in edges:
                                    accepted.append({
                                        "impactParameter": edge["b"],
                                        "nextImpactParameter": edge["nextB"],
                                        "rails": edge["rails"], "railIndices": edge["railIndices"],
                                        "lengthMetres": edge["lengthMetres"],
                                        "incomingSpeed": speed, "incomingRoll": roll,
                                        "incomingEnglish": english,
                                        "departureSpeed": edge["departureSpeed"],
                                        "arrivalSpeed": edge["arrivalSpeed"],
                                        "points": [list(q) for q in edge["points"]]})
            key = "%d_%d" % (first, second)
            matrix[key] = {"feasible": len(accepted) > 0, "acceptedCount": len(accepted),
                           "examples": accepted[:3],
                           "failureStats": graph.stats.get("pair_%d_%d" % (first, second), {}),
                           "seconds": time.time() - started}
            log("  pair %d->%d feasible=%s accepted=%d (%.1f s)"
                % (first, second, len(accepted) > 0, len(accepted), time.time() - started))
    return matrix


def hamiltonian_orders(matrix, balls):
    """Visiting orders that use only feasible pairs."""
    allowed = {(int(k.split("_")[0]), int(k.split("_")[1]))
               for k, v in matrix.items() if v["feasible"]}
    out = []
    for order in canonical_orders_for(balls):
        if all((order[i], order[i + 1]) in allowed for i in range(len(order) - 1)):
            out.append(list(order))
    return out


# --------------------------------------------------------------------------- order search


def plan_rung(m, r2, rung, args, log):
    graph = ChainGraph(m, r2, rung, args)
    positions = graph.positions
    if args.pairs_only:
        log("rung %d: pair relaxation (omit %s)" % (rung, args.omit))
        matrix = pair_matrix(graph, r2, args, log)
        surviving = hamiltonian_orders(matrix, graph.balls)
        return {"rung": rung, "mode": "pair-relaxation", "omitBall": args.omit,
                "balls": list(graph.balls),
                "distanceMetres": m.fixture[rung]["distanceMetres"],
                "ballPositions": {str(k): list(v) for k, v in positions.items()},
                "pairMatrix": matrix,
                "feasiblePairs": sorted(k for k, v in matrix.items() if v["feasible"]),
                "ordersSurvivingPairRelaxation": surviving,
                "closableOrders": [], "perOrder": [], "deepestChains": [],
                "maxDepth": 0, "failureStats": {}, "secondsSpent": 0.0}
    orders = canonical_orders_for(graph.balls)
    if args.orders_from:
        # A directory is read per rung, so one flag covers a five-rung run.
        source = args.orders_from
        if os.path.isdir(source):
            source = os.path.join(source, "plan2-rung%d.json" % rung)
        with open(source, "r", encoding="utf-8") as handle:
            previous = json.load(handle)
        # A pair-relaxation run carries no perOrder list; what it leaves is the set of orders that
        # survived, which is exactly the set worth enumerating (every other order contains a pair
        # that is infeasible for *any* incoming state, so it cannot close).
        if previous.get("mode") == "pair-relaxation":
            # An empty list here is a result, not a missing input: no order avoids all the
            # infeasible pairs, so there is nothing to enumerate. Falling back to all 180 orders
            # would quietly throw that away.
            wanted = {tuple(o) for o in previous["ordersSurvivingPairRelaxation"]}
            orders = [o for o in orders if tuple(o) in wanted]
        else:
            limit = args.order_limit or len(previous.get("perOrder", []))
            wanted = {tuple(entry["order"]) for entry in previous.get("perOrder", [])[:limit]}
            orders = [o for o in orders if tuple(o) in wanted] or orders
        log("rung %d: %d of %d orders survive the pair relaxation"
            % (rung, len(orders), len(canonical_orders_for(graph.balls))))
    if args.order_limit and len(orders) > args.order_limit:
        orders = orders[:args.order_limit]

    # Opening: the cue's own start point is free, so the approach direction to the first ball is a
    # genuine search dimension. The state arriving at the first ball is not free — it is a struck
    # state carried over the opening run, so it comes from the measured arc table: a seed state
    # (what a strike produces) propagated over the opening length.
    openings = []
    speeds, rolls, englishes = r2.arc_grid
    for i in range(0, len(speeds), args.opening_speed_stride):
        for j in range(0, len(rolls), args.opening_roll_stride):
            for k in range(0, len(englishes), args.opening_english_stride):
                seed = (speeds[i], rolls[j], englishes[k])
                arcs = r2.arc_query(seed[0], seed[1], seed[2], args.opening_backoff)
                if not arcs:
                    continue
                # Straightest opening arc; phase 2 refines the aim that realises it. Arrival speed
                # and spin are measured, not assumed.
                sample = min(arcs, key=lambda s: abs(s[1]))
                openings.append((seed, sample))

    closable, per_order, deepest = [], [], []
    started = time.time()
    for order in orders:
        first = order[0]
        centre = graph.positions[first]
        frontier = []
        seen_open = set()
        steps = int(round(360.0 / args.opening_direction_step))
        for step in range(steps):
            heading = from_angle(math.radians(step * args.opening_direction_step))
            source = sub(centre, scale(heading, args.opening_backoff + 2 * BALL_RADIUS))
            for b in graph.b_samples[first]:
                contact, travel, line, phi = graph.solve_contact(source, first, b)
                if not graph.phi_in_window(first, phi):
                    continue
                start = sub(contact, scale(travel, args.opening_backoff))
                if not graph.on_table(start):
                    continue
                if not graph.clear_leg(start, contact, {first}, set(), 0.0):
                    continue
                for seed, sample in openings:
                    arrival_state = (sample[3], sample[4], sample[5])
                    node = (round(arrival_state[0], 2), round(arrival_state[1], 2),
                            round(arrival_state[2], 1), round(phi, 1), b)
                    if node in seen_open:
                        continue
                    seen_open.add(node)
                    frontier.append({"ball": first, "state": arrival_state, "b": b, "phi": phi,
                                     "contact": contact, "travel": travel, "line": line,
                                     "start": start,
                                     "seedSpeed": seed[0], "seedRoll": seed[1],
                                     "seedEnglish": seed[2]})
        if args.opening_rails > 0:
            frontier.extend(rail_first_openings(graph, args, first, openings, seen_open))
        # Keep the frontier diverse: it is built heading-major, so a plain head-of-list cut would
        # leave the search looking at the first few approach directions only (that alone held the
        # first smoke run to depth 1). Stride instead, so every heading stays represented.
        if len(frontier) > args.beam:
            stride = len(frontier) / float(args.beam)
            frontier = [frontier[int(i * stride)] for i in range(args.beam)]
        depth = 1 if frontier else 0
        chains = [[node] for node in frontier]
        best_chain = chains[0] if chains else None
        for index in range(1, len(order)):
            ball, next_ball = order[index - 1], order[index]
            allowed_balls = set(order[index - 1:index + 1])
            allowed_pockets = {BALL_POCKET[x] for x in order[:index]}
            grown = []
            seen_nodes = set()
            for chain in chains:
                last = chain[-1]
                for edge in graph.transitions(ball, last["contact"], last["travel"], last["line"],
                                              last["b"], last["state"], next_ball,
                                              allowed_balls, allowed_pockets):
                    node = (round(edge["arrivalState"][0], 2), round(edge["arrivalState"][1], 2),
                            round(edge["arrivalState"][2], 1), round(edge["nextPhi"], 1),
                            edge["nextB"], edge["rails"])
                    if node in seen_nodes:
                        continue
                    seen_nodes.add(node)
                    _, travel, line, _ = graph.solve_contact(edge["points"][-2], next_ball,
                                                             edge["nextB"])
                    grown.append(chain + [{"ball": next_ball, "b": edge["nextB"],
                                           "phi": edge["nextPhi"], "contact": edge["nextContactXZ"],
                                           "travel": travel, "line": line,
                                           "state": edge["arrivalState"], "edge": edge}])
                    if len(grown) >= args.beam:
                        break
                if len(grown) >= args.beam:
                    break
            if not grown:
                break
            chains = grown
            best_chain = grown[0]
            depth = index + 1
        entry = {"order": list(order), "depth": depth}
        per_order.append(entry)
        if depth == len(order):
            closable.append({"order": list(order), "chain": describe(best_chain)})
        if best_chain:
            deepest.append({"order": list(order), "depth": depth, "chain": describe(best_chain)})
        log("rung %d order %s depth %d (%.1f s)" % (rung, "".join(map(str, order)), depth,
                                                    time.time() - started))
    per_order.sort(key=lambda e: -e["depth"])
    deepest.sort(key=lambda e: -e["depth"])
    return {
        "rung": rung,
        "omitBall": args.omit,
        "balls": list(graph.balls),
        "distanceMetres": m.fixture[rung]["distanceMetres"],
        "ballPositions": {str(k): list(v) for k, v in positions.items()},
        "closableOrders": closable,
        "perOrder": per_order,
        "deepestChains": deepest[:args.keep],
        "maxDepth": max((e["depth"] for e in per_order), default=0),
        "failureStats": graph.stats,
        "secondsSpent": time.time() - started,
    }


def describe(chain):
    """Chain as JSON: one entry per ball, carrying the geometry phase 2 needs to reproduce it."""
    out = []
    for node in chain:
        item = {"ball": node["ball"], "lineOfCentresOffsetDegrees": node["phi"],
                "impactParameterInBallRadii": node["b"],
                "contactXZ": list(node["contact"]),
                "cueStateSpeedRollEnglish": list(node["state"])}
        if "start" in node:
            # With a rail-first opening the cue is not aimed at the ball: the aim is the first leg,
            # towards the cushion. Using the contact-approach direction there would hand phase 2 a
            # starting point that cannot produce the planned route at all.
            points = node.get("openingPoints")
            aim = unit(sub(points[1], points[0])) if points and len(points) > 1 else node["travel"]
            item.update({"cueStartXZ": list(node["start"]),
                         "openingAimRadians": angle_of(aim),
                         "openingRailIndices": node.get("openingRails", []),
                         "openingSeedSpeed": node["seedSpeed"],
                         "openingSeedRollRatio": node["seedRoll"],
                         "openingSeedEnglish": node["seedEnglish"]})
        if "edge" in node:
            edge = node["edge"]
            item.update({"rails": edge["rails"], "railIndices": edge["railIndices"],
                         "lengthMetres": edge["lengthMetres"],
                         "departureSpeed": edge["departureSpeed"],
                         "arrivalSpeed": edge["arrivalSpeed"],
                         "arrivalDirectionErrorDegrees": edge["arrivalDirectionErrorDegrees"],
                         "bulgeMetres": edge["bulgeMetres"],
                         "targetLaunchSpeed": edge["targetLaunchSpeed"],
                         "points": [list(p) for p in edge["points"]]})
        out.append(item)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase0", required=True, help="round-1 phase-0 output root")
    parser.add_argument("--round2-phase0", required=True, help="round-2 phase-0 output root")
    parser.add_argument("--out", required=True)
    parser.add_argument("--rungs", default="0,1,2,3,4")
    parser.add_argument("--phi-step", type=float, default=3.0)
    parser.add_argument("--b-step", type=float, default=0.1)
    parser.add_argument("--max-rails", type=int, default=2)
    parser.add_argument("--arc-angle-tolerance", type=float, default=6.0)
    parser.add_argument("--arrival-angle-tolerance", type=float, default=8.0)
    parser.add_argument("--rail-angle-tolerance", type=float, default=8.0)
    parser.add_argument("--opening-backoff", type=float, default=0.35)
    parser.add_argument("--opening-direction-step", type=float, default=6.0)
    parser.add_argument("--opening-speed-stride", type=int, default=2)
    parser.add_argument("--opening-roll-stride", type=int, default=2)
    parser.add_argument("--opening-english-stride", type=int, default=2)
    parser.add_argument("--beam", type=int, default=200)
    parser.add_argument("--keep", type=int, default=12)
    parser.add_argument("--order-limit", type=int, default=0)
    parser.add_argument("--orders-from", default="")
    parser.add_argument("--unlimited-range", action="store_true",
                        help="drop the two-phase reachability bound (diagnostic: isolates whether "
                             "the cue speed cap is what limits the chain)")
    parser.add_argument("--opening-rails", type=int, default=0,
                        help="max straight rails the cue may take before the first ball "
                             "(0 = round-2 behaviour: straight openings only)")
    parser.add_argument("--opening-start-step", type=float, default=0.3,
                        help="grid step in metres for free cue start positions (rail-first openings)")
    parser.add_argument("--opening-seed-stride", type=int, default=4,
                        help="stride over opening seed states in rail-first openings")
    parser.add_argument("--pot-map-dir", default="",
                        help="pot-map directory; defaults to <phase0>/potmap/pot-map")
    parser.add_argument("--pot-window", default="clean", choices=sorted(Measurements.POT_WINDOW_KEYS),
                        help="clean = spec 3a (no cushion before dropping); v41 = spec 3b (<=2)")
    parser.add_argument("--omit", type=int, default=0, choices=[0] + BALLS,
                        help="spec v5: drop this ball from the layout (0 = the six-ball v4 problem). "
                             "Its pocket stays on the table and stays cue-forbidden.")
    parser.add_argument("--pairs-only", action="store_true",
                        help="run only the ordered-pair relaxation (proof of non-closability)")
    parser.add_argument("--pair-speed-stride", type=int, default=2)
    parser.add_argument("--pair-roll-stride", type=int, default=2)
    parser.add_argument("--pair-witness-cap", type=int, default=200,
                        help="stop a pair sweep once this many feasible transitions are found")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)
    m = Measurements(args.phase0, pot_map_dir=args.pot_map_dir or None, pot_window=args.pot_window)
    r2 = Round2Measurements(args.round2_phase0)

    def log(message):
        if not args.quiet:
            print(message, flush=True)

    active_balls = [b for b in BALLS if b != args.omit]
    summary = {"rungs": [], "settings": {
        "spec": "SIX-POCKET-ONE-SHOT-20260917 v4 round 2, phase 1",
        "omitBall": args.omit,
        "balls": active_balls,
        "visitingOrderClasses": len(canonical_orders_for(active_balls)),
        "correctionOf": "FL-079 single-phase v^2/(2a) reachability prune",
        "slidingDecelerationMeasured": r2.sliding_deceleration,
        "rollingDecelerationMeasured": r2.rolling_deceleration,
        "slideToRollSpeedRatioMeasured": r2.transition_ratio,
        "twoPhaseRangeExamplesMetres": {str(v): r2.max_range(v) for v in (1, 2, 3, 4, 6, 8)},
        "round1SinglePhaseRangeExamplesMetres": {str(v): v * v / (2 * 1.9619997687030726)
                                                 for v in (1, 2, 3, 4, 6, 8)},
        "arcRows": r2.arc_rows, "collisionRows": r2.collision_rows, "railRows": r2.rail_rows,
        "railRetentionMedian": r2.rail_retention_median,
        "railDeviationP05P95": list(r2.rail_deviation_span),
        "arcSeedGrid": {"speeds": r2.arc_grid[0], "rollRatios": r2.arc_grid[1],
                        "englishRadPerSec": r2.arc_grid[2]},
        "collisionSeedGrid": {"speeds": r2.collision_grid[0], "rollRatios": r2.collision_grid[1],
                              "englishRadPerSec": r2.collision_grid[2]},
        "railSeedGrid": {"speeds": r2.rail_grid[0], "rollRatios": r2.rail_grid[1],
                         "englishRadPerSec": r2.rail_grid[2]},
        "phiStepDegrees": args.phi_step, "impactParameterStep": args.b_step,
        "maxRailsPerSegment": args.max_rails,
        "arcAngleToleranceDegrees": args.arc_angle_tolerance,
        "arrivalAngleToleranceDegrees": args.arrival_angle_tolerance,
        "beam": args.beam,
        "potWindow": args.pot_window,
        "potWindowField": m.pot_window_key,
        "potMapDirectory": m.pot_map_dir,
        "potWindowDegreesByRungAndBall": {
            str(rung): {str(ball): m.acceptance(rung, ball)[0] for ball in active_balls}
            for rung in range(5)},
    }}
    for rung in [int(r) for r in args.rungs.split(",") if r != ""]:
        result = plan_rung(m, r2, rung, args, log)
        with open(os.path.join(args.out, "plan2-rung%d.json" % rung), "w", encoding="utf-8") as handle:
            json.dump(result, handle, indent=2, sort_keys=True)
        summary["rungs"].append({"rung": rung, "omitBall": args.omit,
                                 "distanceMetres": result["distanceMetres"],
                                 "closable": len(result["closableOrders"]),
                                 "maxDepth": result["maxDepth"],
                                 "seconds": result["secondsSpent"]})
        log("rung %d d=%.6f closable=%d maxDepth=%d"
            % (rung, result["distanceMetres"], len(result["closableOrders"]), result["maxDepth"]))
    with open(os.path.join(args.out, "experiment-settings.json"), "w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2, sort_keys=True)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Analyze attributed SceneKit display swaps exported by Xcode 26.2 xctrace.

This analyzes presentation only, never GPU busy time or temperature. It requires
an exact, diagnostic-only SceneKit encoder label; generic render labels and an
app PID alone cannot distinguish SwiftUI from SceneKit. Schemas were inspected
in historical Metal System Trace exports. New captures must verify the complete
label -> encoder -> command buffer -> present request -> display swap chain.

Export each table separately: multi-table xctrace exports can omit schemas after
the first table. Inputs: metal-object-label, metal-application-intervals,
ca-client-present-request, display-surface-swap. Time fields are integer ns.

Phase manifest v1 (derive times from app signposts in the SAME trace, not Mac
wall-clock timestamps):
  {"version": 1, "clock": "trace-relative-ns", "pid": 123,
   "evidence_scope": "live", "encoder_label": "QiuJi.DailyClearance3D.Scene",
   "phase_source": {"path": "phase-signposts.xml", "sha256": "..."},
   "phases": [{"name": "aim", "instance": "aim-1", "start_ns": 1000000000,
               "end_ns": 2000000000}, ...]}

Required phases: idle, aim, orbit, break. Repeated phases are allowed. Phase
source bytes are hashed for provenance; phase extraction/semantics need separate
review. This script does not claim overall user-goal acceptance. Historical
schema research can produce statistics but never a passing live frame gate.
The current surface/request temporal join is only a candidate mapping: a real
trace demonstrated swaps preceding the matched encoder's GPU completion. Until
an explicit presentation identity contract is verified, reports are incomplete
and exit 2 even when candidate intervals look smooth. No frame gate can pass.
"""

from __future__ import annotations

import argparse
import bisect
import hashlib
import json
import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


LIMIT_NS = 20_000_000
PASS_FRACTION = 0.95
MIN_INTERVALS = 30
REQUIRED_PHASES = {"idle", "aim", "orbit", "break"}
COMMAND_BUFFER_ROOT_ENCODER = (1 << 64) - 1
RENDER_ENCODER_OBJECT_TYPE = 11  # Inspected Xcode 26.2 metal-object-label schema.


class EvidenceError(ValueError):
    """Evidence is incomplete, ambiguous or inconsistent."""


def integer(value, label: str, positive: bool = False) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise EvidenceError(f"{label} must be an integer")
    if value < (1 if positive else 0):
        raise EvidenceError(f"{label} is outside its valid range")
    return value


class Table:
    def __init__(self, path: Path, expected_schema: str, required: set[str]):
        self.path = Path(path)
        root = ET.parse(self.path).getroot()
        self.ids = {}
        for elem in root.iter():
            if key := elem.get("id"):
                if key in self.ids:
                    raise EvidenceError(f"{self.path}: duplicate XML id {key}")
                self.ids[key] = elem
        nodes = root.findall("node")
        if len(nodes) != 1:
            raise EvidenceError(f"{self.path}: export exactly one table per file")
        schema = nodes[0].find("schema")
        if schema is None or schema.get("name") != expected_schema:
            raise EvidenceError(f"{self.path}: expected schema {expected_schema}")
        cols = [x.findtext("mnemonic") for x in schema.findall("col")]
        if len(cols) != len(set(cols)) or not required.issubset(cols):
            raise EvidenceError(f"{self.path}: missing or duplicate columns")
        self.rows = []
        for row in nodes[0].findall("row"):
            if len(row) != len(cols):
                raise EvidenceError(f"{self.path}: row/column count mismatch")
            self.rows.append(dict(zip(cols, (self.resolve(x) for x in row))))
        if not self.rows:
            raise EvidenceError(f"{self.path}: no samples")

    def resolve(self, elem):
        seen = set()
        while key := elem.get("ref"):
            if key in seen or key not in self.ids:
                raise EvidenceError(f"{self.path}: invalid XML reference {key}")
            seen.add(key)
            elem = self.ids[key]
        return elem

    def number(self, row, key: str) -> int:
        text = row[key].text
        if text is None or not text.isdecimal():
            raise EvidenceError(f"{self.path}: missing/non-integer {key}")
        return int(text)

    def pid(self, row) -> int | None:
        process = row["process"]
        if process.tag == "sentinel":
            return None
        elem = process.find("pid")
        if elem is None:
            raise EvidenceError(f"{self.path}: process has no numeric PID")
        elem = self.resolve(elem)
        if elem.text is None or not elem.text.isdecimal():
            raise EvidenceError(f"{self.path}: invalid PID")
        return int(elem.text)

    def descendants(self, elem, ancestors=frozenset()):
        """Resolve nested formatted-label/thread references without trusting fmt."""
        elem = self.resolve(elem)
        identity = id(elem)
        if identity in ancestors:
            raise EvidenceError(f"{self.path}: cyclic nested XML reference")
        yield elem
        for child in elem:
            yield from self.descendants(child, ancestors | {identity})


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_manifest(path: Path):
    data = json.loads(path.read_text())
    if data.get("version") != 1 or data.get("clock") != "trace-relative-ns":
        raise EvidenceError("Unsupported phase manifest version or clock")
    pid = integer(data.get("pid"), "pid", positive=True)
    if data.get("evidence_scope") not in {"live", "historical_schema_research"}:
        raise EvidenceError("Declare live or historical_schema_research evidence_scope")
    label = data.get("encoder_label")
    if not isinstance(label, str) or not label.startswith("QiuJi.DailyClearance3D."):
        raise EvidenceError("A dedicated daily 3D SceneKit encoder label is required")
    source = data.get("phase_source", {})
    if not isinstance(source.get("path"), str) or not source.get("sha256"):
        raise EvidenceError("Missing phase signpost source and SHA-256")
    source_path = path.parent / source["path"]
    if sha256(source_path) != source["sha256"]:
        raise EvidenceError("Phase signpost source SHA-256 mismatch")
    phases = data.get("phases")
    if not isinstance(phases, list) or not phases:
        raise EvidenceError("No phase windows")
    instances = set()
    for phase in phases:
        if phase.get("name") not in REQUIRED_PHASES | {"shot"}:
            raise EvidenceError(f"Unknown phase {phase.get('name')}")
        instance = phase.get("instance")
        if not isinstance(instance, str) or not instance or instance in instances:
            raise EvidenceError("Phase instance IDs must be unique nonempty strings")
        instances.add(instance)
        a = integer(phase.get("start_ns"), "phase start_ns")
        b = integer(phase.get("end_ns"), "phase end_ns")
        if b <= a:
            raise EvidenceError("Phase must have a positive duration")
    phases.sort(key=lambda p: p["start_ns"])
    if any(a["end_ns"] > b["start_ns"] for a, b in zip(phases, phases[1:])):
        raise EvidenceError("Phase windows overlap; define exclusive operating phases")
    missing = REQUIRED_PHASES - {p["name"] for p in phases}
    if missing:
        raise EvidenceError(f"Missing required phases: {sorted(missing)}")
    return data, pid, label, source_path


def attributed_buffers(labels: Table, encoders: Table, pid: int, marker: str):
    """Return CB identity -> proven root interval (None for legacy schema).

    Xcode 26.2 real exports anchor encoder label timestamps at the command-buffer
    root start, before the child Encoding interval. Such markers need the exact
    structured child event label and a unique enclosing root, not a time slack.
    Reused identities are conservatively rejected; no allocation epoch is guessed.
    """
    fields = set(encoders.rows[0])
    structured = {"event-type", "event-label"}.issubset(fields)
    if not structured and fields & {"event-type", "event-label"}:
        raise EvidenceError("Incomplete structured encoder label schema")
    if structured and "object-type" not in labels.rows[0]:
        raise EvidenceError("Structured encoder attribution requires marker object-type")
    history = {}
    for row in labels.rows:
        if labels.number(row, "pid") != pid:
            continue
        history.setdefault(labels.number(row, "object-id"), []).append(row)
    if not any(r["label"].text == marker for rows in history.values() for r in rows):
        raise EvidenceError("No exact SceneKit encoder markers for the requested PID")

    roots, children, identities = {}, {}, {}
    for row in encoders.rows:
        if encoders.pid(row) != pid or (structured and row["event-type"].text != "Encoding"):
            continue
        cb = encoders.number(row, "cmdbuffer-id")
        encoder = encoders.number(row, "encoder-id")
        start = encoders.number(row, "start")
        interval = (start, start + encoders.number(row, "duration"))
        if structured and encoder == COMMAND_BUFFER_ROOT_ENCODER:
            roots.setdefault(cb, []).append(interval)
        else:
            children.setdefault(cb, []).append((row, interval))
            identities.setdefault(encoder, []).append((row, interval))

    buffers, matches = {}, 0
    for encoder, candidates in identities.items():
        for row, interval in candidates:
            start, end = interval
            cb = encoders.number(row, "cmdbuffer-id")
            if structured:
                nodes = list(encoders.descendants(row["event-label"]))
                names = [n.text for n in nodes if n.tag == "metal-object-label"]
                if marker in names and names != [marker]:
                    raise EvidenceError("Ambiguous structured encoder label")
                if names != [marker]:
                    continue
                if any(encoders.pid({"process": n}) != pid for n in nodes if n.tag == "process"):
                    raise EvidenceError("Structured encoder label has a conflicting PID")
                if len(roots.get(cb, [])) != 1:
                    raise EvidenceError("Missing or reused command-buffer root interval")
                root_start, root_end = roots[cb][0]
                if root_end <= root_start or not root_start <= start < end <= root_end:
                    raise EvidenceError("Marked encoder is outside its command-buffer root interval")
                marker_rows = [r for r in history.get(encoder, [])
                               if root_start <= labels.number(r, "timestamp") <= root_end]
            else:
                marker_rows = [r for r in history.get(encoder, [])
                               if start <= labels.number(r, "timestamp") <= end]
            if not any(r["label"].text == marker for r in marker_rows):
                continue
            if any(r["label"].text != marker for r in marker_rows):
                raise EvidenceError("Encoder relabeling makes attribution ambiguous")
            if structured and any(labels.number(r, "object-type") != RENDER_ENCODER_OBJECT_TYPE
                                  for r in marker_rows):
                raise EvidenceError("Marker is not a render encoder object")
            if len(candidates) != 1:
                raise EvidenceError("Reused encoder identity makes attribution ambiguous")
            if structured:
                # Other passes in this buffer are valid only inside the same root.
                if any(not root_start <= a < b <= root_end for _, (a, b) in children[cb]):
                    raise EvidenceError("Reused command-buffer identity outside its root interval")
                buffers[cb] = (root_start, root_end)
            else:
                if len(children[cb]) != 1:
                    raise EvidenceError("Ambiguous command-buffer identity in legacy schema")
                buffers[cb] = None
            matches += 1
    if not buffers:
        raise EvidenceError("SceneKit marker did not match any encoder lifetime with exact attribution")
    return buffers, matches


def analyze(manifest: Path, labels_path: Path, encoders_path: Path,
            requests_path: Path, swaps_path: Path):
    data, pid, marker, phase_source = validate_manifest(manifest)
    labels = Table(labels_path, "metal-object-label",
                   {"timestamp", "object-id", "label", "pid"})
    encoders = Table(encoders_path, "metal-application-intervals",
                     {"start", "duration", "process", "encoder-id", "cmdbuffer-id"})
    requests = Table(requests_path, "ca-client-present-request",
                     {"timestamp", "cmdbuffer-id", "surface-id", "process"})
    swaps = Table(swaps_path, "display-surface-swap",
                  {"timestamp", "surface-id", "swap-id", "display-name", "framebuffer-index"})

    buffers, encoder_matches = attributed_buffers(labels, encoders, pid, marker)

    all_requests = {}
    own_times = []
    presented_buffers = set()
    seen_requests = set()
    for row in requests.rows:
        t = requests.number(row, "timestamp")
        cb = requests.number(row, "cmdbuffer-id")
        surface = requests.number(row, "surface-id")
        row_pid = requests.pid(row)
        identity = (t, cb, surface, row_pid)
        if identity in seen_requests:
            raise EvidenceError("Duplicate present requests")
        seen_requests.add(identity)
        all_requests.setdefault(surface, []).append((t, cb, row_pid))
        if row_pid == pid and cb in buffers:
            if cb in presented_buffers:
                raise EvidenceError("Reused marked command-buffer identity in present requests")
            if buffers[cb] is not None and t < buffers[cb][1]:
                raise EvidenceError("Present request precedes marked command-buffer root completion")
            presented_buffers.add(cb)
            own_times.append(t)
    if not own_times:
        raise EvidenceError("No presentation requests from marked SceneKit buffers")
    for entries in all_requests.values():
        entries.sort()
    streams = set()
    frames = []
    consumed = set()
    seen_swaps = set()
    for row in sorted(swaps.rows, key=lambda r: swaps.number(r, "timestamp")):
        t = swaps.number(row, "timestamp")
        surface = swaps.number(row, "surface-id")
        swap = swaps.number(row, "swap-id")
        swap_key = (t, swap, swaps.number(row, "framebuffer-index"))
        if swap_key in seen_swaps:
            raise EvidenceError("Duplicate display swaps")
        seen_swaps.add(swap_key)
        entries = all_requests.get(surface, [])
        idx = bisect.bisect_right(entries, (t, math.inf, math.inf)) - 1
        if idx < 0:
            continue  # Unknown/system surfaces and capture boundary truncation.
        request_t, cb, row_pid = entries[idx]
        if row_pid != pid or cb not in buffers:
            continue  # SwiftUI and other process streams are intentionally excluded.
        request_key = (surface, request_t, cb)
        if request_key in consumed:
            # A repeated scanout is not a newly presented SceneKit frame.
            continue
        consumed.add(request_key)
        streams.add((row["display-name"].text, swaps.number(row, "framebuffer-index")))
        frames.append({"present_ns": t, "request_ns": request_t,
                       "command_buffer": cb, "surface": surface, "swap": swap})
    if not frames:
        raise EvidenceError("No actual display swaps attributed to SceneKit")
    if len(streams) != 1:
        raise EvidenceError("Ambiguous display/framebuffer streams; analyze one display")
    # No two independently presented marked streams may contribute at the same
    # instant. This also catches accidental marker use by two SceneKit views.
    times = [f["present_ns"] for f in frames]
    if len(times) != len(set(times)):
        raise EvidenceError("Multiple marked streams presented at the same timestamp")

    phase_results = []
    all_intervals = []
    for phase in data["phases"]:
        a, b = phase["start_ns"], phase["end_ns"]
        if a < min(own_times) or b > max(f["present_ns"] for f in frames):
            raise EvidenceError(f"{phase['instance']}: phase extends beyond retained SceneKit evidence")
        phase_times = [t for t in times if a <= t <= b]
        record = dict(phase, candidate_presented_frames=len(phase_times))
        if phase["name"] == "idle":
            record["interval_gate"] = "not_applicable_intentional_idle"
            phase_results.append(record)
            continue
        intervals = [y - x for x, y in zip(phase_times, phase_times[1:])]
        if len(intervals) < MIN_INTERVALS:
            raise EvidenceError(f"{phase['instance']}: only {len(intervals)} presented intervals; need {MIN_INTERVALS}")
        if any(x <= 0 for x in intervals):
            raise EvidenceError("Nonpositive presented interval")
        first_latency = phase_times[0] - a
        tail_hold = b - phase_times[-1]
        sorted_intervals = sorted(intervals)
        passing = sum(x <= LIMIT_NS for x in intervals)
        fraction = passing / len(intervals)
        # Report boundary stalls separately. Do not fold a preceding idle hold
        # into active pacing or silently hide unpresented time at either boundary.
        boundary_pass = first_latency <= LIMIT_NS and tail_hold <= LIMIT_NS
        record.update(candidate_intervals=len(intervals), candidate_fraction_le_20ms=fraction,
                      candidate_p95_ms=sorted_intervals[math.ceil(0.95 * len(intervals)) - 1] / 1e6,
                      candidate_max_ms=max(intervals) / 1e6,
                      candidate_first_present_after_operation_ms=first_latency / 1e6,
                      candidate_terminal_hold_lower_bound_ms=tail_hold / 1e6,
                      candidate_boundary_threshold_met=boundary_pass,
                      candidate_interval_threshold_met=fraction >= PASS_FRACTION,
                      boundary_20ms_check="unverified_presentation_identity",
                      interval_gate="unverified_presentation_identity")
        phase_results.append(record)
        all_intervals.extend(intervals)
    fraction = sum(x <= LIMIT_NS for x in all_intervals) / len(all_intervals)
    sources = {str(p): sha256(p) for p in [manifest, phase_source, labels_path,
                                          encoders_path, requests_path, swaps_path]}
    result = {
        "evidence_valid": False, "evidence_scope": data["evidence_scope"], "pid": pid,
        "presentation_attribution_complete": False,
        "candidate_statistics_only": True,
        "error": "Presentation identity/GPU readiness is unverified; latest preceding request by surface is insufficient.",
        "encoder_label": marker, "sources_sha256": sources,
        "attribution": {"marked_encoders": encoder_matches, "marked_command_buffers": len(buffers),
                        "marked_present_requests": len(own_times), "candidate_display_swaps": len(frames),
                        "candidate_display_stream": list(next(iter(streams))),
                        "candidate_unpresented_or_truncated_requests": len(own_times) - len(frames)},
        "phases": phase_results, "candidate_active_fraction_le_20ms": fraction,
        "frame_interval_gate_passed": False,
        "boundary_20ms_check_passed": False,
        "overall_goal_accepted": False,
        "limitations": ["All presentations and interval statistics below use an unverified candidate join and cannot establish displayed-frame pacing.",
                        "Exact structured labels prove encoder/command-buffer ownership, not which content a display swap presents.",
                        "Reused encoder or command-buffer identities are rejected rather than assigned guessed allocation epochs.",
                        "Phase manifest extraction and exclusive phase semantics require review against source signposts.",
                        "GPU cost, image quality, 10-minute thermal and normal-launch acceptance are outside this report.",
                        "Boundary 20ms checks are separate conservative diagnostics, not a new user acceptance threshold.",
                        "A different final presentation buffer or composited surface without this direct attribution is rejected, not inferred."],
        "candidate_presentations": frames,
    }
    return result, 2


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for arg in ("manifest", "labels", "encoders", "requests", "swaps"):
        parser.add_argument(f"--{arg}", required=True, type=Path)
    args = parser.parse_args()
    try:
        report, status = analyze(args.manifest, args.labels, args.encoders, args.requests, args.swaps)
    except (EvidenceError, OSError, ET.ParseError, json.JSONDecodeError) as error:
        report, status = {"evidence_valid": False, "frame_interval_gate_passed": False,
                          "overall_goal_accepted": False, "error": str(error)}, 2
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return status


if __name__ == "__main__":
    sys.exit(main())

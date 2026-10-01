#!/usr/bin/env python3
"""Summarize opt-in rendering CPU section samples; not GPU or frame presentation."""
import argparse
import hashlib
import json
import math
import statistics
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path


def summarize(values):
    assert values and all(math.isfinite(v) and v >= 0 for v in values)
    ordered = sorted(values)
    return {
        "count": len(values),
        "meanMS": statistics.fmean(values),
        "medianMS": statistics.median(values),
        "p95MS": ordered[math.ceil(len(ordered) * .95) - 1],
        "maxMS": ordered[-1],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.input.suffix == ".xml":
        root = ET.parse(args.input).getroot()
        ids = {node.attrib["id"]: node for node in root.iter() if "id" in node.attrib}
        def resolved(node):
            return ids[node.attrib["ref"]] if "ref" in node.attrib else node
        categories = {"SceneKit": "SCN", "contact": "MobileContactOcclusion",
                      "renderUpdate": "renderUpdate", "probe": "RenderCodeCPUProbe",
                      "syntheticReplay": "testRenderCodeCPUBaseline"}
        inclusive, leaves = Counter(), Counter()
        total = 0
        usable = 0
        for row in root.findall(".//row"):
            weight = row.find("weight")
            stack = row.find("backtrace")
            if weight is None or stack is None:
                continue
            weight = float(resolved(weight).text or 0)
            frames = [resolved(frame).attrib.get("name", "")
                      for frame in resolved(stack).findall("frame")]
            if not weight or not frames:
                continue
            total += weight
            usable += 1
            leaves[frames[0]] += weight
            for name, needle in categories.items():
                if any(needle in frame for frame in frames):
                    inclusive[name] += weight
        assert usable > 0 and total > 0
        result = {"sourceSHA256": hashlib.sha256(args.input.read_bytes()).hexdigest(),
                  "weightedRows": usable, "totalSampleWeightMS": total / 1e6,
                  "inclusiveSampleWeightPercent": {key: value / total * 100 for key, value in inclusive.items()},
                  "topLeafSampleWeightMS": [(key, value / 1e6) for key, value in leaves.most_common(15)],
                  "limits": ["Partial simulator process capture; includes fixture and test framework.",
                             "Inclusive categories overlap and are not CPU utilization or full frame time.",
                             "SCN prefix is a coarse stack category, not exclusive SceneKit attribution."]}
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return
    data = json.loads(args.input.read_text())
    if "runs" in data:
        runs = []
        for run in data["runs"]:
            assert run["dropped"] == 0
            values = run["samplesMS"]["labels"]
            assert len(values) == 1_200
            runs.append({"run": run["run"], "changingGeometry": run["changingGeometry"],
                         "labels": summarize(values)})
        result = {"sourceSHA256": hashlib.sha256(args.input.read_bytes()).hexdigest(),
                  "os": data["os"], "scope": data["scope"], "runs": runs,
                  "limits": ["Direct CPU calls, not whole frames or real-device performance.",
                             "Visualization preparation, SceneKit rendering and GPU cost excluded."]}
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        for run in runs:
            print(run["run"], "changing" if run["changingGeometry"] else "unchanged", run["labels"])
        return
    assert data["physicsInMeasuredWindow"] is False
    phases = []
    for phase in data["phases"]:
        assert phase["dropped"] == 0 and phase["wallSeconds"] >= 20
        sections = {key: summarize(values) for key, values in phase["samplesMS"].items()}
        assert sections["frame"]["count"] > 100 and sections["contact"]["count"] > 100
        phases.append({
            "mode": phase["mode"], "wallSeconds": phase["wallSeconds"],
            "viewport": phase["viewport"], "requestedFPS": phase["requestedFPS"],
            "msaa": phase["msaa"], "sections": sections,
            "callbackHz": sections["frame"]["count"] / phase["wallSeconds"],
        })
    summary = {
        "sourceSHA256": hashlib.sha256(args.input.read_bytes()).hexdigest(),
        "os": data["os"], "phases": phases,
        "clockRead": summarize(data["clockReadMS"]["frame"]),
        "probeRecordAverageMS": data["probeRecordAverageMS"],
        "limits": [
            "Frame timing includes sub-sections and their probe overhead; do not sum them.",
            "Contact timing is on the renderer callback thread; it is not additive to the main loop.",
            "Callback frequency is not presented FPS.",
            "Fixed positional replay does not measure the whole App, GPU or heat.",
            "Object allocation and GPU time require separate profiling.",
        ],
    }
    args.output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    for phase in phases:
        print(phase["mode"], "callbackHz", round(phase["callbackHz"], 2))
        for key, value in phase["sections"].items():
            print(f"  {key}: n={value['count']} mean={value['meanMS']:.5f}ms "
                  f"p95={value['p95MS']:.5f}ms")


if __name__ == "__main__":
    main()

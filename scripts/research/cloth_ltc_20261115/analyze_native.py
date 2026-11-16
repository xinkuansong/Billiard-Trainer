"""Summarize R6's current-scene XCTest without rerendering or discarding samples."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics

import numpy as np
from PIL import Image, ImageDraw


def panels(images, labels, output):
    width, height = images[0].size
    result = Image.new("RGB", (width * len(images), height + 28), (22, 22, 22))
    draw = ImageDraw.Draw(result)
    for index, (image, label) in enumerate(zip(images, labels)):
        result.paste(image, (index * width, 28))
        draw.text((index * width + 8, 8), label, fill="white")
    result.save(output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, exist_ok=True)
    attachments = args.source / "attachments"
    manifest = json.loads((attachments / "manifest.json").read_text())
    files = {
        item["suggestedHumanReadableName"].split("_0_")[0]: attachments / item["exportedFileName"]
        for row in manifest for item in row["attachments"]
    }
    source = files["h18-r6-current-scene"]
    report = json.loads(source.read_text())
    assert report["completed"] and len(report["quality"]) == 16
    quality = []
    for record in report["quality"]:
        state = record["state"]
        a = np.array(Image.open(files[f"h18-r6-{state}-A"]).convert("RGB"))
        b = np.array(Image.open(files[f"h18-r6-{state}-B"]).convert("RGB"))
        signed = b.astype(np.int16) - a.astype(np.int16)
        delta = abs(signed).max(axis=2)
        assert int(delta.max()) == record["maximum"]
        for level in [1, 2, 4, 8]:
            assert int((delta > level).sum()) == record["over"][str(level)]
        quality.append({**record, "denominator": "whole image, not a cloth ROI",
                        "overPercent": {str(level): float((delta > level).mean() * 100) for level in [1, 2, 4, 8]},
                        "meanMaxChannel": float(delta.mean()), "meanSignedRGB": signed.mean(axis=(0, 1)).tolist(),
                        "percentiles": dict(zip(["p95", "p99", "p99_9"], np.percentile(delta, [95, 99, 99.9]).tolist()))})
        if state in [0, 8, 13]:
            heat = np.zeros_like(a)
            heat[:, :, 0] = np.minimum(delta * 60, 255)
            heat[:, :, 1] = np.minimum(delta * 15, 255)
            panels([Image.fromarray(a), Image.fromarray(b)], ["A: current production", "B: single LTC"], args.evidence / f"state-{state}-comparison.png")
            Image.fromarray(heat).save(args.evidence / f"state-{state}-difference-x60.png")
            # Inspect an actual local maximum; no interpolation of the saved pixel evidence.
            y, x = np.unravel_index(delta.argmax(), delta.shape)
            x = max(0, min(a.shape[1] - 256, int(x) - 128))
            y = max(0, min(a.shape[0] - 256, int(y) - 128))
            crops = [Image.fromarray(v[y:y + 256, x:x + 256]).resize((512, 512), Image.Resampling.NEAREST) for v in [a, b, heat]]
            panels(crops, ["A: 2x nearest", "B: 2x nearest", "Difference x60"], args.evidence / f"state-{state}-crop.png")
    timing = {}
    for metric in ["gpuSpanMS", "cpuEncodeMS", "cpuWallMS"]:
        timing[metric] = {}
        for kind in ["AA", "AB"]:
            groups = []
            for cycle in range(6):
                arms = {arm: [frame[metric] for row in report["times"] if row["kind"] == kind and row["cycle"] == cycle and row["arm"] == arm for frame in row["frames"]] for arm in ["A", "B"]}
                assert all(len(values) == 96 for values in arms.values())
                av, bv = statistics.median(arms["A"]), statistics.median(arms["B"])
                groups.append({"cycle": cycle, "aMS": av, "bMS": bv, "decreasePercent": (av - bv) / av * 100})
            timing[metric][kind] = {"groups": groups, "medianDecreasePercent": statistics.median(g["decreasePercent"] for g in groups),
                                    "positiveGroups": sum(g["decreasePercent"] > 0 for g in groups)}
    result = {"source": str(source), "sourceSHA256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "device": report["device"], "scope": report["scope"], "lookupBytes": report["lookupBytes"],
              "quality": quality, "timing": timing, "thermalStates": sorted({row["thermal"] for row in report["times"]}),
              "interpretation": "GPU timestamps include the complete current SceneKit scene. CPU wall includes synchronous GPU wait; it is not CPU computation or energy."}
    (args.evidence / "native-review.json").write_text(json.dumps(result, indent=2) + "\n")
    print(args.evidence / "native-review.json")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Strict offline consumer for the native production fixed-scene XCTest.

Usage: python3 analyze_native_production.py EVIDENCE [--out new-summary.json]
EVIDENCE is run_native_app.py's retained evidence directory (or its attachments
directory). Required: result/launcher/hash-after/snapshot-manifest, xcresulttool
test-summary/test-details, and the exported attachments/manifest.json. No tool,
App, GPU, network or build is invoked. PNG decoding uses only the standard library.
--self-test exercises synthetic refusal cases; it is not a native measurement.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics
import struct
import sys
import zlib

SELECTOR = "QiuJiTests/ClothSupportPerformanceResearchTests/testNativeProductionGuardComboGPUComparison"
VARIANT = "legacy-cone-plus-safe-hoisted-finite-domain-guard-r1-20261113"
REFERENCE = "9495698875cd01a4ecd8d00708ce88bf9989c6e118805620f99a11d03dcca390"
CANDIDATE = "ca5acc70043f0da620e2c6501188063c78027c8e26b62233d128ced01f81aabd"
EMITTER = "65c4665f3e1221ee507eefe9fd4e3e6513de2581fa9818a253e67e190ef3db42"
CORE = "8f2753a642a9e0da466389406a374fdc25fc47f0026b0dccff91efa9f8fd3495"
CALIBRATION = "08d8e2fb0e3bf6129fc6b0c2001a8ca8b1d2e8e0a292fba4bd07d59eab898eb9"
METRICS = ("gpuSpanMS", "cpuEncodeMS", "cpuCommitWaitMS", "cpuWallMS", "cpuFullSyncWallMS")
SCOPE = ("Native Mac complete production fixed SceneKit scene, installed guard TaiNi.surface "
         "versus original R on the same R room reflection probe, actual balls and room. "
         "Excludes probe generation, SwiftUI page, presentation FPS, live camera/physics/input "
         "and sustained device/phone behavior. CPU and GPU intervals are not additive.")


class Rejected(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise Rejected(message)


def number(value, where, positive=True):
    require(type(value) in (int, float) and math.isfinite(value), where + ": finite numeric value required")
    require(value > 0 if positive else value >= 0, where + ": value outside range")
    return float(value)


def close(actual, expected, where):
    require(type(actual) in (int, float) and math.isfinite(actual), where + ": invalid aggregate")
    require(math.isclose(actual, expected, rel_tol=1e-8, abs_tol=1e-8),
            f"{where}: aggregate mismatch {actual!r} != {expected!r}")


def read_json(path):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f"{path}: duplicate JSON key {key}")
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=pairs,
                      parse_constant=lambda token: (_ for _ in ()).throw(Rejected(f"{path}: {token}")))


def file_record(path):
    return {"path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def distribution(values):
    require(bool(values) and all(math.isfinite(x) for x in values), "Empty/nonfinite distribution")
    ordered = sorted(values)
    return {"n": len(values), "p50": statistics.median(values),
            "p95": ordered[math.ceil(.95 * len(values)) - 1],
            "p99": ordered[math.ceil(.99 * len(values)) - 1],
            "minimum": ordered[0], "maximum": ordered[-1]}


def quantile(values, fraction):
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    low, high = math.floor(position), math.ceil(position)
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def check_test_result(summary, details):
    require(summary.get("result") == "Passed", "xcresult overall result is not Passed")
    for key, expected in (("totalTestCount", 1), ("passedTests", 1), ("failedTests", 0),
                          ("skippedTests", 0), ("expectedFailures", 0)):
        require(type(summary.get(key)) is int and summary[key] == expected, "xcresult " + key + " mismatch")
    require(summary.get("testFailures", []) == [], "xcresult has testFailures")
    if "totalFailureCount" in summary:
        require(summary["totalFailureCount"] == 0, "xcresult totalFailureCount is nonzero")
    cases = []

    def visit(node, target=""):
        require("Failure" not in node.get("nodeType", ""), "xcresult details contain failure nodes")
        if node.get("nodeType") in ("Unit test bundle", "UI test bundle"):
            target = node["name"]
        if "result" in node:
            require(node["result"] == "Passed", "xcresult details contain non-Passed node")
        if node.get("nodeType") == "Test Case":
            cases.append((target + "/" + node["nodeIdentifier"].removesuffix("()"), node.get("result")))
        for child in node.get("children", []):
            visit(child, target)
    for node in details["testNodes"]:
        visit(node)
    require(cases == [(SELECTOR, "Passed")], "xcresult must contain exactly the native scene selector, Passed")
    return {"selector": SELECTOR, "result": "Passed", "passed": 1, "failed": 0, "skipped": 0}


def provenance(evidence):
    names = ("result.json", "launcher.json", "hash-after.json", "snapshot-manifest.json",
             "test-summary.json", "test-details.json")
    data = {name: read_json(evidence / name) for name in names}
    result, launch, after, manifest = [data[n] for n in names[:4]]
    require(result.get("status") == "succeeded", "Launcher did not succeed")
    require(launch.get("selectors") == [SELECTOR], "Launcher selector mismatch")
    destination = launch.get("destination", "")
    require("platform=macOS" in destination and "Designed for iPad" in destination,
            "Launcher is not the native Designed for iPad destination")
    require(launch.get("configuration") == "Debug -O", "Unexpected build configuration")
    require(after.get("snapshotVerified") is True and after.get("cloneVerified") is True
            and after.get("changedOrMissing") == [] and after.get("added") == [] and "error" not in after,
            "Post-run source integrity failed or is incomplete")
    body = {k: v for k, v in manifest.items() if k != "snapshot_id"}
    expected = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()
    require(manifest.get("schema") == 1 and manifest.get("snapshot_id") == expected
            and result.get("snapshotID") == expected, "Snapshot/launcher identity mismatch")
    source_names = ("QiuJiTests/ClothSupportPerformanceResearchTests.swift",
                    "QiuJiTests/ClothResearchShaders.swift", "QiuJi/Core/Scene/DailyClothSupportExperiment.swift",
                    "QiuJi/Core/Scene/MobileReferenceLighting.swift", "QiuJi/Core/Scene/AngleTrainingScene.swift",
                    "QiuJi/Core/Scene/RoomReflectionProbe.swift")
    sources = {name: manifest["files"][name]["sha256"] for name in source_names}
    test = check_test_result(data["test-summary.json"], data["test-details.json"])
    return {"snapshotID": expected, "test": test, "sourceSHA256": sources,
            "evidence": {name: file_record(evidence / name) for name in names},
            "integrityScope": "Snapshot manifest self-hash and launcher post-run clone verification; no rebuild or rescan of reclaimed work."}


class Attachments:
    def __init__(self, directory):
        self.directory = directory.resolve()
        self.manifest = directory / "manifest.json"
        groups = read_json(self.manifest)
        matching = [g for g in groups if g.get("testIdentifierURL", "").endswith("/" + SELECTOR)]
        require(len(matching) == 1, "Exactly one attachment group must match the native selector")
        self.items = matching[0]["attachments"]
        require(all(a.get("isAssociatedWithFailure") is False for a in self.items), "Failure-associated attachment exists")

    def get(self, logical, extension):
        matches = [a for a in self.items if
                   (a.get("suggestedHumanReadableName", "") == logical + extension
                    or a.get("suggestedHumanReadableName", "").startswith(logical + "_"))
                   and a.get("exportedFileName", "").lower().endswith(extension)]
        require(len(matches) == 1, f"Expected exactly one attachment {logical}{extension}")
        path = (self.directory / matches[0]["exportedFileName"]).resolve()
        require(path.parent == self.directory and path.is_file(), "Missing or escaping attachment file")
        return path


def png_rgba(path):
    """Decode ordinary noninterlaced 8-bit RGB/RGBA PNG losslessly; reject others."""
    data = path.read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n", f"{path}: invalid PNG signature")
    offset, header, compressed, ended = 8, None, bytearray(), False
    while offset < len(data):
        require(offset + 12 <= len(data), "Truncated PNG chunk")
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        end = offset + length + 12
        require(end <= len(data), "Truncated PNG data")
        payload = data[offset + 8:end - 4]
        crc = struct.unpack_from(">I", data, end - 4)[0]
        require(zlib.crc32(kind + payload) & 0xffffffff == crc, "PNG CRC mismatch")
        if kind == b"IHDR":
            require(header is None and offset == 8 and length == 13, "Invalid PNG IHDR")
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            require(length == 0 and end == len(data), "Invalid PNG ending")
            ended = True
        elif kind[0] & 32 == 0:
            require(kind == b"PLTE", f"Unsupported critical PNG chunk {kind!r}")
        offset = end
    require(header is not None and ended, "Incomplete PNG")
    width, height, depth, color, compression, filtering, interlace = header
    require(0 < width <= 2800 and 0 < height <= 1600 and depth == 8 and color in (2, 6)
            and compression == filtering == interlace == 0, "Unsupported PNG dimensions/format (need 8-bit RGB/RGBA, noninterlaced)")
    bpp = 3 if color == 2 else 4
    stride = width * bpp
    decoder = zlib.decompressobj()
    raw = decoder.decompress(compressed, (stride + 1) * height + 1)
    require(decoder.eof and not decoder.unused_data and len(raw) == (stride + 1) * height,
            "PNG decompressed size mismatch")
    pixels = bytearray()
    previous = bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        mode = raw[start]
        require(mode <= 4, "Unknown PNG row filter")
        row = bytearray(raw[start + 1:start + 1 + stride])
        for x in range(stride) if mode else ():
            a = row[x - bpp] if x >= bpp else 0
            b = previous[x]
            c = previous[x - bpp] if x >= bpp else 0
            if mode == 1:
                row[x] = (row[x] + a) & 255
            elif mode == 2:
                row[x] = (row[x] + b) & 255
            elif mode == 3:
                row[x] = (row[x] + ((a + b) // 2)) & 255
            elif mode == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                row[x] = (row[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        if bpp == 4:
            pixels.extend(row)
        else:
            rgba = bytearray(width * 4)
            rgba[0::4], rgba[1::4], rgba[2::4], rgba[3::4] = row[0::3], row[1::3], row[2::3], b"\xff" * width
            pixels.extend(rgba)
        previous = row
    require(all(a == 255 for a in pixels[3::4]), "Nonopaque PNG requires a reviewed premultiplication contract; refusing raw BGRA-count claims")
    return width, height, bytes(pixels)


def pixel_stats(rgba):
    green = red = magenta = 0
    colors = set()
    for i in range(0, len(rgba), 4):
        r, g, b = rgba[i:i + 3]
        green += g > 35 and g * 10 > r * 11 and g * 10 > b * 11
        red += r > 100 and r > g * 2 and r > b * 2
        magenta += r > 230 and g < 30 and b > 230
        colors.add(((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3))
    return {"greenPixels": green, "redPixels": red, "magentaPixels": magenta, "uniqueRGB565": len(colors)}


def image_proof(attachments, row):
    prefix = "cloth-native-mac-guard-" + row["fixture"] + "-"
    paths = {name: attachments.get(prefix + name, ".png") for name in
             ("reference", "candidate", "candidate-repeat", "restored", "red-control")}
    width, height, baseline = png_rgba(paths["reference"])
    require([width, height] == row["resolution"], "PNG resolution differs from fixture")
    stats = pixel_stats(baseline)
    count = width * height
    require(stats["uniqueRGB565"] > 128 and stats["greenPixels"] > count // 100 and stats["magentaPixels"] == 0,
            "Reference PNG is empty, lacks cloth, or contains shader-error magenta")
    require(row["baselineGreenPixels"] == stats["greenPixels"] and row["baselineUniqueRGB565"] == stats["uniqueRGB565"],
            "Reference image counters do not match actual PNG")
    for name in ("candidate", "candidate-repeat", "restored"):
        w, h, pixels = png_rgba(paths[name])
        require((w, h) == (width, height) and pixels == baseline, name + " PNG is not RGBA exact")
    w, h, control = png_rgba(paths["red-control"])
    require((w, h) == (width, height), "Control dimensions differ")
    changed = sum(baseline[i:i + 4] != control[i:i + 4] for i in range(0, len(baseline), 4))
    control_stats = pixel_stats(control)
    require(changed > count // 100 and control_stats["redPixels"] > stats["redPixels"] + count // 100,
            "Red control does not affect at least 1% of actual image")
    require(row["controlChangedPixels"] == changed and row["candidateMaximumRGBAError"] == 0,
            "Reported image proof counters differ from PNG")
    close(row["controlAffectedPixelFraction"], changed / count, "control coverage")
    return {"independentlyDecodedPNGs": 5, "exactComparisonsToReference": 3,
            "reference": stats, "redControl": control_stats, "changedPixels": changed,
            "files": {name: file_record(path) for name, path in paths.items()},
            "sameLastTargetProof": "36 timed-slot checks are harness-attested via complete raw slots and cycle flags; their pixels/hashes were not individually exported, so not independently redecoded."}


def installed(meta):
    for key, value in (("requested", True), ("effective", True), ("requestedVariant", "guard-combo"),
                       ("variant", VARIANT), ("fallbackReason", "none"), ("capacity", 16),
                       ("contactSlots", 16), ("profile", "R"), ("sampling", "reference"),
                       ("expectedSurfaceSHA256", CANDIDATE)):
        require(meta.get(key) == value, "Installed program " + key + " mismatch")
    require(meta["requested"] is True and meta["effective"] is True, "Installed flags must be booleans")
    n = meta["clothMaterials"]
    require(type(n) is int and n > 0 and meta["surfaceSHA256"] == [CANDIDATE] * n
            and meta["geometryModifierCount"] == n and len(meta["normalIntensities"]) == n,
            "Installed program material/golden mismatch")
    require(all(abs(number(x, "normalIntensity") - .65) < .00001 for x in meta["normalIntensities"]),
            "Installed normal intensity changed")


def calibration(report):
    require(report.get("passed") is True and report.get("schema") == 1
            and report.get("executionPlatform") == "MacNative-isiOSAppOnMac"
            and report.get("isiOSAppOnMac") is True and report.get("shaderSHA256") == CALIBRATION,
            "Native calibration identity or pass flag invalid")
    number(report["targetAllocatedBytes"], "calibration target bytes")
    raw, warmups = report["raw"], report["warmups"]
    require(len(raw) == 36 and len(warmups) == 8, "Calibration sample count mismatch")
    previous = 0.0
    for i, sample in enumerate(warmups + raw):
        if i < 8:
            cycle, slot, expected = i // 2, i % 2, (32 if i % 2 == 0 else 1024)
        else:
            index = i - 8
            cycle, slot = index // 4, index % 4
            expected = ((32, 1024, 1024, 32) if cycle % 2 == 0 else (1024, 32, 32, 1024))[slot]
        require(sample["cycle"] == cycle and sample["slot"] == slot and sample["iterations"] == expected
                and sample["commandStatus"] == 4, "Calibration order or command completion mismatch")
        start, end = [number(sample[k], "calibration " + k) for k in ("gpuStartTime", "gpuEndTime")]
        require(end > start and start >= previous, "Calibration GPU intervals invalid or overlap")
        previous = end
        close(sample["gpuMS"], (end - start) * 1000, "calibration GPU span")
        encode = number(sample["cpuEncodeMS"], "calibration encode")
        wait = number(sample["cpuCommitWaitMS"], "calibration commit/wait")
        close(sample["syncWallMS"], encode + wait, "calibration CPU wall")
    ratios = []
    for cycle in range(9):
        slots = raw[cycle * 4:cycle * 4 + 4]
        ratios.append(statistics.median(s["gpuMS"] for s in slots if s["iterations"] == 1024)
                      / statistics.median(s["gpuMS"] for s in slots if s["iterations"] == 32))
    require(len(report["pairedRatios"]) == 9, "Calibration ratio count mismatch")
    for a, b in zip(report["pairedRatios"], ratios):
        close(a, b, "calibration paired ratio")
    close(report["medianHeavyLightRatio"], statistics.median(ratios), "calibration median ratio")
    bits = report["lastPixelHalfBits"]
    require(statistics.median(ratios) > 1.5 and min(ratios) > 1.2 and len(bits) == 4
            and all(type(x) is int and 0 <= x < 65536 for x in bits) and bits[0] != 0 and bits[3] == 0x3c00,
            "Calibration workload sensitivity/readback gate failed")
    return {"passed": True, "rawSamples": 36, "warmups": 8, "pairedRatios": ratios,
            "medianHeavyLightRatio": statistics.median(ratios), "shaderSHA256": CALIBRATION,
            "readbackScope": "Four half bits are report-attested; no calibration pixel image is independently supplied."}


def header(report):
    require(report.get("completed") is True and report.get("performanceRankingAllowed") is True,
            "Incomplete/nonranking native report")
    # Frozen r8 predates this producer field; its independent xcresult gate is
    # mandatory above. Newer reports may not contradict it with recorded failures.
    if "recordedXCTestFailureCount" in report:
        require(type(report["recordedXCTestFailureCount"]) is int and report["recordedXCTestFailureCount"] == 0,
                "Report recorded XCTest failures despite completion flags")
    require(report.get("schema") == 2 and report.get("harness") == "sequential-command-buffer-r4"
            and report.get("executionPlatform") == "MacNative-isiOSAppOnMac"
            and report.get("isiOSAppOnMac") is True and str(report.get("environment", "")).startswith("MacNative:"),
            "Not the validated native sequential host")
    require(report.get("MSAA") == 4 and report.get("framesPerBatch") == 6 and report.get("cycles") == 9
            and report.get("fixtureCount") in (4, 5, 6, 7) and len(report["rows"]) == report["fixtureCount"],
            "Native fixture/batch/cycle counts mismatch")
    require(all(type(report[k]) is int for k in ("MSAA", "framesPerBatch", "cycles", "fixtureCount")),
            "Native sample counts must be integers")
    require(report.get("candidate") == VARIANT and report.get("emitterSHA256") == EMITTER
            and report.get("referenceCoreSHA256") == CORE, "Top-level source golden mismatch")
    require(report.get("format") == "BGRA8Unorm_sRGB with depth32Float_stencil8", "Render target format changed")
    require("share" in report.get("probeCostScope", "") and "production R" in report["probeCostScope"],
            "Missing shared-R-probe cost boundary")
    require(report["thermalStart"] in (0, 1) and report["thermalEnd"] in (0, 1), "Invalid native thermal boundaries")
    installed(report["installedProgram"])
    return calibration(report["gpuCalibration"])


def frame_values(frame, index, previous):
    require(frame["frame"] == index, "Per-slot frame index mismatch")
    values = {k: number(frame[k], k) for k in METRICS}
    start, end = [number(frame[k], k) for k in ("gpuStartTime", "gpuEndTime")]
    require(end > start and start >= previous, "Sequential frame GPU timestamps overlap or are invalid")
    close(values["gpuSpanMS"], (end - start) * 1000, "frame GPU timestamps")
    close(values["cpuWallMS"], values["cpuEncodeMS"] + values["cpuCommitWaitMS"], "frame CPU wall sum")
    sentinel = number(frame["sentinelClearWallMSExcluded"], "sentinel clear wall")
    require(values["cpuFullSyncWallMS"] + 1e-8 >= values["cpuWallMS"] + sentinel,
            "Full sync wall excludes part of sentinel/render")
    return values, end


def analyze_row(row, attachments, program):
    require(row.get("performanceRankingAllowed") is True and row.get("completedCycles") == 9
            and len(row["cycles"]) == 9 and row.get("sameLastTargetChecks") == 36,
            "Fixture incomplete, nonranking or incorrect same-target count")
    require(row.get("installedProgram") == program, "Row program provenance differs from top-level")
    require(row.get("contactSlots") == 16 and row.get("room") == "tournament"
            and row.get("cloth") == "green" and row.get("table") == "charcoal", "Fixture appearance/slot contract changed")
    n = row["clothMaterials"]
    require(type(n) is int and n > 0 and row["referenceSurfaceSHA256"] == [REFERENCE] * n
            and row["candidateSurfaceSHA256"] == [CANDIDATE] * n, "Fixture surface golden mismatch")
    width, height = row["resolution"]
    require(row["pixels"] == width * height, "Fixture pixel count mismatch")
    balls = row["visibleBalls"]
    expected_keys = ["cueBall"] + [f"_{i}" for i in range(1, balls)]
    require(row["ballKeys"] == expected_keys and [b["id"] for b in row["balls"]] == expected_keys,
            "Visible production ball identity mismatch")
    require(len(row["cameraTransform"]) == 16 and all(type(v) in (float, int) and math.isfinite(v) for v in row["cameraTransform"]),
            "Invalid camera matrix")
    require(row["cameraSettings"].get("wantsHDR") is True, "Native production camera HDR is disabled")
    allocated = row["harnessAllocatedBytes"]
    sizes = [number(allocated[k], "allocated " + k) for k in ("color", "MSAA", "depthStencil", "staging")]
    close(allocated["total"], sum(sizes), "harness target allocation total")
    frames = {arm: {k: [] for k in METRICS} for arm in ("reference", "candidate")}
    metric_cycles = {k: [] for k in METRICS}
    previous = 0.0
    for cycle_index, cycle in enumerate(row["cycles"]):
        expected = ["reference", "candidate", "candidate", "reference"] if cycle_index % 2 == 0 else ["candidate", "reference", "reference", "candidate"]
        require(cycle["index"] == cycle_index and cycle["order"] == expected
                and cycle.get("sameLastTargetBitwiseExact") is True and len(cycle["rawBatchTiming"]) == 4,
                "ABBA/BAAB order or same-target proof mismatch")
        slots = {k: {"reference": [], "candidate": []} for k in METRICS}
        spans = []
        for variant, slot in zip(expected, cycle["rawBatchTiming"]):
            require(slot["variant"] == variant and slot["frames"] == 6 and len(slot["perFrameTiming"]) == 6,
                    "Raw slot variant or frame count mismatch")
            values = {k: [] for k in METRICS}
            for index, frame in enumerate(slot["perFrameTiming"]):
                v, previous = frame_values(frame, index, previous)
                for key in METRICS:
                    values[key].append(v[key]); frames[variant][key].append(v[key])
            for key in ("gpuSpanMS", "cpuEncodeMS", "cpuWallMS"):
                close(slot[key], sum(values[key]), "slot " + key)
            require(number(slot["batchWallMSIncludingHarness"], "batch wall") + 1e-8 >= sum(values["cpuFullSyncWallMS"]),
                    "Batch wall is shorter than its six full-sync frames")
            for key in METRICS:
                slots[key][variant].append(statistics.mean(values[key]))
            spans.append(statistics.mean(values["gpuSpanMS"]))
        require(len(cycle["gpuMillisecondsPerRender"]) == 4, "Cycle span count mismatch")
        for a, b in zip(cycle["gpuMillisecondsPerRender"], spans):
            close(a, b, "cycle span")
        for key in METRICS:
            a, b = slots[key]["reference"], slots[key]["candidate"]
            am, bm = statistics.median(a), statistics.median(b)
            record = {"index": cycle_index, "order": expected, "referenceSlotMeansMS": a,
                      "candidateSlotMeansMS": b, "referenceMedianMS": am, "candidateMedianMS": bm,
                      "pairedDeltaMS": bm - am, "pairedChangePercent": (bm / am - 1) * 100,
                      "referenceEndpointDriftPercent": abs(a[1] - a[0]) / am * 100,
                      "candidateEndpointDriftPercent": abs(b[1] - b[0]) / bm * 100,
                      "referenceSignedEndpointChangePercent": (a[1] / a[0] - 1) * 100,
                      "candidateSignedEndpointChangePercent": (b[1] / b[0] - 1) * 100}
            metric_cycles[key].append(record)
            if key == "gpuSpanMS":
                for field in ("referenceMedianMS", "candidateMedianMS", "pairedChangePercent",
                              "referenceEndpointDriftPercent", "candidateEndpointDriftPercent"):
                    close(cycle[field], record[field], "reported cycle " + field)
    result_metrics = {}
    for key in METRICS:
        for arm in frames:
            require(len(frames[arm][key]) == 108, "Need exactly 108 frames per arm")
            calculated = distribution(frames[arm][key])
            reported = row[arm + "FrameDistribution"]
            require(reported["n"] == 108 and reported[key]["n"] == 108, "Reported distribution count mismatch")
            for field, value in calculated.items():
                close(reported[key][field], value, "reported frame distribution " + key + "/" + field)
        records = metric_cycles[key]
        changes = [r["pairedChangePercent"] for r in records]
        baseline = [r["referenceMedianMS"] for r in records]
        result_metrics[key] = {"referenceFrames": distribution(frames["reference"][key]),
            "candidateFrames": distribution(frames["candidate"][key]), "cycles": records,
            "pairedChangeMedianPercent": statistics.median(changes),
            "pairedChangeIQRPercent": [quantile(changes, .25), quantile(changes, .75)],
            "pairedChangeMinimumPercent": min(changes), "pairedChangeMaximumPercent": max(changes),
            "candidateFasterCycles": sum(x < 0 for x in changes),
            "referenceCycleMediansMS": baseline,
            "referenceFirstToLastCycleChangePercent": (baseline[-1] / baseline[0] - 1) * 100,
            "referenceMaximumEndpointDriftPercent": max(r["referenceEndpointDriftPercent"] for r in records),
            "candidateMaximumEndpointDriftPercent": max(r["candidateEndpointDriftPercent"] for r in records)}
    for key in ("pairedChangeMedianPercent", "pairedChangeMinimumPercent", "pairedChangeMaximumPercent",
                "candidateFasterCycles", "referenceMaximumEndpointDriftPercent", "candidateMaximumEndpointDriftPercent"):
        close(row[key], result_metrics["gpuSpanMS"][key], "reported row " + key)
    return {"fixture": row["fixture"], "resolution": row["resolution"], "pixels": row["pixels"],
            "visibleBalls": balls, "pose": row["pose"], "layout": row["layout"], "metrics": result_metrics,
            "harnessAllocatedBytes": allocated, "imageProof": image_proof(attachments, row),
            "sameLastTargetChecksHarnessAttested": 36, "timedFrames": 216,
            "gpuFrameMedianNanosecondsPerTargetPixel": {
                arm: statistics.median(frames[arm]["gpuSpanMS"]) * 1_000_000 / row["pixels"]
                for arm in frames},
            "pixelNormalizationScope": "Whole target pixels; not cloth fragment count or universal throughput"}


def analyze(directory):
    evidence = directory.parent if directory.name == "attachments" else directory
    proof = provenance(evidence)
    attachments = Attachments(evidence / "attachments")
    report_path = attachments.get("cloth-native-mac-production-guard-gpu", ".json")
    report = read_json(report_path)
    cal = header(report)
    require(report["gpuCalibration"]["device"] == report["device"], "Calibration device mismatch")
    standalone = read_json(attachments.get("cloth-native-mac-fill-calibration", ".json"))
    require(standalone == report["gpuCalibration"], "Embedded and standalone calibration reports differ")
    donor = read_json(attachments.get("cloth-guard-production-installed-program", ".json"))
    require(donor == report["installedProgram"], "Standalone installed-program metadata differs")
    expected = []
    for width, height in [(700, 400), (1400, 800)] + ([(2800, 1600)] if report["fixtureCount"] in (6, 7) else []):
        expected += [(f"pair-2-near-{width}x{height}", 2, "pair", "near", [width, height]),
                     (f"scatter-16-overview-{width}x{height}", 16, "scatter", "overview", [width, height])]
    if report["fixtureCount"] in (5, 7):
        expected += [("rack-16-overview-1400x800", 16, "rack", "overview", [1400, 800])]
    actual = [(r["fixture"], r["visibleBalls"], r["layout"], r["pose"], r["resolution"]) for r in report["rows"]]
    require(actual == expected, "Expected exact 4/6-row legacy or 5/7-row rack-extended native fixture matrix, in declared order")
    rows = [analyze_row(r, attachments, report["installedProgram"]) for r in report["rows"]]
    return {"schema": 1, "accepted": True, "scope": SCOPE, "performanceRankingAllowed": True,
            "notVerified": ["Individual timed-slot image pixels are not exported; 36 checks/fixture are harness attestations",
                            "Per-frame MTL completion is enforced by the passed harness, not independently encoded status fields",
                            "Onscreen presentation, phone performance and complete SwiftUI page costs"],
            "provenance": proof, "report": file_record(report_path),
            "attachmentsManifest": file_record(attachments.manifest), "calibration": cal,
            "device": report["device"], "os": report["os"], "fixtureCount": len(rows),
            "percentiles": "Frame P50 median; P95/P99 nearest rank. Cycle IQR linearly interpolated. Six-frame batch means form each ABBA slot.",
            "totalTimedFrames": len(rows) * 216, "totalSameLastTargetChecksHarnessAttested": len(rows) * 36,
            "totalPNGsIndependentlyDecoded": len(rows) * 5, "rows": rows}


def self_test():
    rejected = []
    cases = {
        "incomplete_report": lambda: header({"completed": False, "performanceRankingAllowed": True}),
        "false_ranking": lambda: header({"completed": True, "performanceRankingAllowed": False}),
        "reported_xctest_failure": lambda: header({"completed": True, "performanceRankingAllowed": True,
                                                   "recordedXCTestFailureCount": 1}),
        "simulator_disguised_as_completed": lambda: header({"completed": True, "performanceRankingAllowed": True,
                                                          "schema": 2, "harness": "sequential-command-buffer-r4",
                                                          "executionPlatform": "Simulator"}),
        "nan_metric": lambda: number(float("nan"), "synthetic"),
        "bool_metric": lambda: number(True, "synthetic"),
        "fabricated_gpu_span": lambda: frame_values({"frame": 0, "gpuStartTime": 1, "gpuEndTime": 1.001,
            "gpuSpanMS": 2, "cpuEncodeMS": 1, "cpuCommitWaitMS": 2, "cpuWallMS": 3,
            "cpuFullSyncWallMS": 4, "sentinelClearWallMSExcluded": 1}, 0, 0),
        "xcresult_failure_despite_passed_string": lambda: check_test_result({"result": "Passed", "totalTestCount": 1,
            "passedTests": 1, "failedTests": 1, "skippedTests": 0, "expectedFailures": 0}, {}),
        "zero_tests": lambda: check_test_result({"result": "Passed", "totalTestCount": 0}, {}),
        "wrong_selector": lambda: check_test_result({"result": "Passed", "totalTestCount": 1, "passedTests": 1,
            "failedTests": 0, "skippedTests": 0, "expectedFailures": 0}, {"testNodes": [{"nodeType": "Unit test bundle",
            "name": "QiuJiTests", "result": "Passed", "children": [{"nodeType": "Test Case", "nodeIdentifier": "Other/test()", "result": "Passed"}]}]}),
    }
    for name, action in cases.items():
        try:
            action()
        except Rejected as error:
            rejected.append({"case": name, "rejected": str(error)})
        else:
            raise AssertionError("Synthetic refusal failed: " + name)
    return {"selfTest": "synthetic rejection cases only", "nativeResults": None, "cases": rejected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path, nargs="?")
    parser.add_argument("--out", type=Path, help="Write a new file exclusively; never overwrite evidence")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if not args.self_test and args.evidence is None:
        parser.error("evidence directory is required")
    try:
        result = self_test() if args.self_test else analyze(args.evidence.resolve())
        text = json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + "\n"
        if args.out:
            with args.out.open("x") as stream:
                stream.write(text)
            print(str(args.out.resolve()))
        else:
            print(text, end="")
        return 0
    except (Rejected, OSError, ValueError, KeyError, TypeError, IndexError, struct.error, zlib.error) as error:
        print(json.dumps({"accepted": False, "performanceRankingAllowed": False,
                          "error": str(error), "errorType": type(error).__name__}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Run the current iPhone/iPad simulator matrix with isolated, auditable evidence."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import html
import json
import os
import re
import shlex
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import zlib
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = REPO / "scripts/simulator-matrix.json"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
FINGERPRINT_ROOTS = ("QiuJi", "QiuJiTests", "QiuJiUITests")
FINGERPRINT_STANDALONE = (
    "project.yml",
    "QiuJi.xcodeproj/project.pbxproj",
    "scripts/Makefile",
    "scripts/run_simulator_matrix.py",
    "scripts/simulator-matrix.json",
    "scripts/simulator-regression-tests.txt",
)
FINGERPRINT_CONTENT_LIMIT = 2 * 1024 * 1024


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def slug(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-")


def source_fingerprint(config_path: Path) -> str:
    """Fingerprint the app/test inputs so resume never reuses stale green evidence.

    Small files are content-hashed. Large media/model files use size + mtime: this
    keeps the check fast in a repo with multi-GB videos while still invalidating a
    local run when an input asset changes.
    """
    candidates = {config_path.resolve()}
    for relative in FINGERPRINT_STANDALONE:
        candidates.add((REPO / relative).resolve())
    for relative in FINGERPRINT_ROOTS:
        root = REPO / relative
        candidates.update(path.resolve() for path in root.rglob("*") if path.is_file())

    digest = hashlib.sha256()
    for path in sorted(candidates, key=lambda item: str(item)):
        try:
            stat = path.stat()
        except FileNotFoundError:
            continue
        try:
            label = str(path.relative_to(REPO))
        except ValueError:
            label = str(path)
        digest.update(label.encode("utf-8"))
        digest.update(b"\0")
        digest.update(str(stat.st_size).encode("ascii"))
        digest.update(b"\0")
        if stat.st_size <= FINGERPRINT_CONTENT_LIMIT:
            digest.update(path.read_bytes())
        else:
            digest.update(str(stat.st_mtime_ns).encode("ascii"))
        digest.update(b"\0")
    return digest.hexdigest()


def run(
    command: list[str],
    *,
    cwd: Path = REPO,
    log: Path | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    started = utc_now()
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True, env=env)
    if log is not None:
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(
            json.dumps(
                {
                    "started_at": started,
                    "finished_at": utc_now(),
                    "command": command,
                    "command_shell": shlex.join(command),
                    "exit_code": completed.returncode,
                    "stdout": completed.stdout,
                    "stderr": completed.stderr,
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
    return completed


def load_config(path: Path) -> dict[str, Any]:
    config = json.loads(path.read_text(encoding="utf-8"))
    if config.get("schema_version") != 1:
        raise ValueError("unsupported simulator matrix schema")
    return config


@dataclass(frozen=True)
class ResolvedDevice:
    matrix_id: str
    tier: str
    runtime_version: str
    runtime_identifier: str
    name: str
    udid: str
    device_type: str
    role: str

    def as_dict(self) -> dict[str, str]:
        return {
            "matrix_id": self.matrix_id,
            "tier": self.tier,
            "runtime_version": self.runtime_version,
            "runtime_identifier": self.runtime_identifier,
            "name": self.name,
            "udid": self.udid,
            "device_type": self.device_type,
            "role": self.role,
        }


def simulator_inventory() -> dict[str, Any]:
    completed = run(["xcrun", "simctl", "list", "-j", "runtimes", "devices"])
    if completed.returncode:
        raise RuntimeError(completed.stderr or completed.stdout)
    return json.loads(completed.stdout)


def resolve_devices(config: dict[str, Any]) -> list[ResolvedDevice]:
    inventory = simulator_inventory()
    runtime_by_version = {
        item["version"]: item
        for item in inventory["runtimes"]
        if item.get("isAvailable", True) and item.get("platform") == "iOS"
    }
    resolved: list[ResolvedDevice] = []
    for requested in config["devices"]:
        version = requested["runtime"]
        runtime = runtime_by_version.get(version)
        if runtime is None:
            raise RuntimeError(f"missing available iOS runtime {version} for {requested['id']}")
        candidates = [
            item
            for item in inventory["devices"].get(runtime["identifier"], [])
            if item.get("isAvailable", True)
            and item.get("name") == requested["name"]
            and item.get("deviceTypeIdentifier") == requested["type"]
        ]
        if len(candidates) != 1:
            raise RuntimeError(
                f"{requested['id']} expected one device named {requested['name']} "
                f"of type {requested['type']} on iOS {version}, found {len(candidates)}"
            )
        device = candidates[0]
        resolved.append(
            ResolvedDevice(
                matrix_id=requested["id"],
                tier=requested["tier"],
                runtime_version=version,
                runtime_identifier=runtime["identifier"],
                name=device["name"],
                udid=device["udid"],
                device_type=device["deviceTypeIdentifier"],
                role=requested["role"],
            )
        )
    return resolved


def selectors_for_suite(config: dict[str, Any], suite: str) -> list[str]:
    raw = config["suites"][suite]
    if isinstance(raw, list):
        return raw
    selector_file = REPO / raw["selector_file"]
    selectors = [
        line.strip()
        for line in selector_file.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    selector_slice = raw.get("selector_slice")
    if selector_slice is None:
        return selectors
    if (
        not isinstance(selector_slice, list)
        or len(selector_slice) != 2
        or not all(isinstance(value, int) for value in selector_slice)
    ):
        raise ValueError(f"{suite} selector_slice must be [start, end]")
    start, end = selector_slice
    if start < 0 or end <= start or end > len(selectors):
        raise ValueError(
            f"{suite} selector_slice {selector_slice} is outside 0...{len(selectors)}"
        )
    return selectors[start:end]


def expected_manifest(config: dict[str, Any]) -> set[str]:
    names: set[str] = set()
    for line in (REPO / config["manifest"]).read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        names.add(Path(line.split()[-1]).name)
    return names


def png_pixels(path: Path) -> tuple[int, int, list[tuple[int, ...]]]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("invalid PNG signature")
    cursor = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = interlace = 0
    payload = bytearray()
    while cursor < len(data):
        length = struct.unpack(">I", data[cursor : cursor + 4])[0]
        kind = data[cursor + 4 : cursor + 8]
        chunk = data[cursor + 8 : cursor + 8 + length]
        cursor += length + 12
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            payload.extend(chunk)
        elif kind == b"IEND":
            break
    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(color_type)
    if bit_depth != 8 or interlace != 0 or channels is None:
        raise ValueError(f"unsupported PNG bitDepth={bit_depth} colorType={color_type} interlace={interlace}")
    raw = zlib.decompress(bytes(payload))
    stride = width * channels
    rows: list[bytes] = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        current = bytearray(raw[offset + 1 : offset + 1 + stride])
        offset += stride + 1
        for index in range(stride):
            left = current[index - channels] if index >= channels else 0
            up = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 1:
                current[index] = (current[index] + left) & 0xFF
            elif filter_type == 2:
                current[index] = (current[index] + up) & 0xFF
            elif filter_type == 3:
                current[index] = (current[index] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                estimate = left + up - upper_left
                distances = (abs(estimate - left), abs(estimate - up), abs(estimate - upper_left))
                predictor = (left, up, upper_left)[distances.index(min(distances))]
                current[index] = (current[index] + predictor) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"unsupported PNG filter {filter_type}")
        rows.append(bytes(current))
        previous = current
    step = max(1, (width * height) // 10000)
    pixels: list[tuple[int, ...]] = []
    flat_index = 0
    for row in rows:
        for x in range(0, stride, channels):
            if flat_index % step == 0:
                pixels.append(tuple(row[x : x + channels]))
            flat_index += 1
    return width, height, pixels


def png_dimensions(path: Path) -> tuple[int, int]:
    """Read the original PNG dimensions without expanding every scanline in Python."""
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or not header.startswith(PNG_SIGNATURE) or header[12:16] != b"IHDR":
        raise ValueError("invalid PNG signature or IHDR")
    return struct.unpack(">II", header[16:24])


def is_near_solid(pixels: list[tuple[int, ...]]) -> bool:
    if not pixels:
        return True
    rgb = [pixel[:3] if len(pixel) >= 3 else pixel * 3 for pixel in pixels]
    ranges = [max(p[index] for p in rgb) - min(p[index] for p in rgb) for index in range(3)]
    unique = len(set(rgb))
    return unique <= 8 or max(ranges) < 8


def allowed_duplicate(group: list[str], allowlist: list[list[str]]) -> bool:
    actual = set(group)
    return any(actual == set(allowed) for allowed in allowlist)


def write_contact_sheet(image_dir: Path, images: list[Path]) -> None:
    cards = "\n".join(
        f'<figure><img loading="lazy" src="screenshots/{html.escape(path.name)}">'
        f'<figcaption>{html.escape(path.name)}</figcaption></figure>'
        for path in images
    )
    document = f"""<!doctype html><meta charset="utf-8"><title>v50 contact sheet</title>
<style>body{{font:12px -apple-system;margin:16px;background:#222;color:#eee}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:12px}}
figure{{margin:0;background:#111;padding:8px;border-radius:8px}}img{{width:100%;height:260px;object-fit:contain;background:#000}}
figcaption{{padding-top:6px;word-break:break-all}}</style><div class="grid">{cards}</div>"""
    (image_dir.parent / "contact-sheet.html").write_text(document, encoding="utf-8")


def audit_images(config: dict[str, Any], image_dir: Path, suite: str) -> dict[str, Any]:
    started = time.perf_counter()
    images = sorted(image_dir.glob("*.png"))
    failures: list[str] = []
    details: list[dict[str, Any]] = []
    hashes: dict[str, list[str]] = {}
    expected = expected_manifest(config) if suite == "tour" else set()
    produced = {path.name for path in images}
    if expected:
        missing = sorted(expected - produced)
        extra = sorted(produced - expected)
        if len(images) != config["expected_tour_screenshots"]:
            failures.append(f"expected {config['expected_tour_screenshots']} PNGs, found {len(images)}")
        if missing:
            failures.append("missing manifest images: " + ", ".join(missing))
        if extra:
            failures.append("unexpected images: " + ", ".join(extra))
    dimensions: set[tuple[int, int]] = set()
    # iPad screenshots contain ~3.4M pixels. Unfiltering all 66 PNGs byte by byte
    # in Python added about five minutes after XCTest had already passed. Let
    # ImageIO (`sips`) decode the originals once into tiny temporary thumbnails;
    # the existing deterministic pixel audit then runs on those thumbnails.
    # The original files remain the source for manifest, byte size, SHA-256 and
    # IHDR dimensions, while a missing thumbnail is treated as a decode failure.
    with tempfile.TemporaryDirectory(prefix="qiuji-v50-image-audit-") as temporary:
        thumbnail_dir = Path(temporary)
        if images:
            thumbnail_result = run(
                ["/usr/bin/sips", "-Z", "48", "--out", str(thumbnail_dir), *map(str, images)]
            )
            if thumbnail_result.returncode != 0:
                failures.append(
                    "ImageIO thumbnail decode failed: "
                    + (thumbnail_result.stderr or thumbnail_result.stdout).strip()
                )
        for path in images:
            size = path.stat().st_size
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            hashes.setdefault(digest, []).append(path.name)
            item: dict[str, Any] = {"name": path.name, "bytes": size, "sha256": digest}
            if size == 0:
                failures.append(f"empty file: {path.name}")
            try:
                width, height = png_dimensions(path)
                _, _, pixels = png_pixels(thumbnail_dir / path.name)
                item.update({"width": width, "height": height, "near_solid": is_near_solid(pixels)})
                dimensions.add((width, height))
                if item["near_solid"]:
                    failures.append(f"near-solid screenshot: {path.name}")
            except Exception as error:  # audit must record corrupt/unsupported files, not crash silently
                item["decode_error"] = str(error)
                failures.append(f"cannot decode {path.name}: {error}")
            details.append(item)
    if len(dimensions) > 1:
        failures.append(f"mixed PNG dimensions: {sorted(dimensions)}")
    duplicates = [sorted(names) for names in hashes.values() if len(names) > 1]
    for group in duplicates:
        if not allowed_duplicate(group, config.get("duplicate_allowlist", [])):
            failures.append("unapproved duplicate hash: " + ", ".join(group))
    write_contact_sheet(image_dir, images)
    result = {
        "status": "passed" if not failures else "failed",
        "count": len(images),
        "dimensions": [list(value) for value in sorted(dimensions)],
        "missing": sorted(expected - produced),
        "duplicates": duplicates,
        "failures": failures,
        "duration_seconds": round(time.perf_counter() - started, 3),
        "images": details,
    }
    (image_dir.parent / "image-audit.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return result


def artifact_root(config: dict[str, Any]) -> Path:
    return (REPO / config["artifact_root"]).resolve()


def unit_directory(root: Path, device: ResolvedDevice, appearance: str, state: str, suite: str) -> Path:
    return root / f"ios-{device.runtime_version}" / f"{device.matrix_id}-{slug(device.name)}" / appearance / state / suite


def safe_reset(path: Path, root: Path) -> None:
    resolved = path.resolve()
    if root not in resolved.parents:
        raise RuntimeError(f"refusing to reset path outside artifact root: {resolved}")
    if resolved.exists():
        shutil.rmtree(resolved)
    resolved.mkdir(parents=True)


def set_simulator_state(
    device: ResolvedDevice,
    appearance: str,
    content_size: str | None,
    state: str,
    leaf: Path,
) -> list[dict[str, Any]]:
    contrast = "enabled" if state == "high-contrast" else "disabled"
    commands: list[tuple[str, list[str], set[int]]] = [
        ("boot", ["xcrun", "simctl", "boot", device.udid], {0, 149}),
        ("bootstatus", ["xcrun", "simctl", "bootstatus", device.udid, "-b"], {0}),
        ("appearance", ["xcrun", "simctl", "ui", device.udid, "appearance", appearance], {0}),
        ("appearance-readback", ["xcrun", "simctl", "ui", device.udid, "appearance"], {0}),
        ("increase-contrast", ["xcrun", "simctl", "ui", device.udid, "increase_contrast", contrast], {0}),
        ("increase-contrast-readback", ["xcrun", "simctl", "ui", device.udid, "increase_contrast"], {0}),
    ]
    if content_size:
        commands.append(("content-size", ["xcrun", "simctl", "ui", device.udid, "content_size", content_size], {0}))
        commands.append(("content-size-readback", ["xcrun", "simctl", "ui", device.udid, "content_size"], {0}))
    results: list[dict[str, Any]] = []
    for label, command, allowed in commands:
        completed = run(command, log=leaf / f"command-{label}.json")
        results.append({"label": label, "command": command, "exit_code": completed.returncode})
        if completed.returncode not in allowed:
            raise RuntimeError(f"{label} failed for {device.matrix_id}: {completed.stderr or completed.stdout}")
    return results


def run_unit(
    config: dict[str, Any],
    device: ResolvedDevice,
    appearance: str,
    state: str,
    suite: str,
    *,
    resume: bool,
    content_size: str | None,
    fingerprint: str,
) -> dict[str, Any]:
    root = artifact_root(config)
    leaf = unit_directory(root, device, appearance, state, suite)
    prior = leaf / "unit-summary.json"
    if resume and prior.exists():
        summary = json.loads(prior.read_text(encoding="utf-8"))
        if (
            summary.get("status") == "passed"
            and summary.get("image_audit", {}).get("status") == "passed"
            and summary.get("source_fingerprint") == fingerprint
        ):
            summary["resume_action"] = "skipped_verified_pass"
            return summary
    safe_reset(leaf, root)
    screenshots = leaf / "screenshots"
    screenshots.mkdir()

    summary: dict[str, Any] = {
        "started_at": utc_now(),
        "device": device.as_dict(),
        "appearance": appearance,
        "state": state,
        "suite": suite,
        "source_fingerprint": fingerprint,
        "artifact_directory": str(leaf),
        "status": "failed",
    }
    try:
        resolved_content_size = content_size or config.get("content_sizes", {}).get(state)
        if resolved_content_size is None:
            raise RuntimeError(
                f"state {state!r} has no content size mapping; pass --content-size or add it to config"
            )
        summary["content_size"] = resolved_content_size
        summary["simulator_setup"] = set_simulator_state(
            device, appearance, resolved_content_size, state, leaf
        )
        result_bundle = leaf / "result.xcresult"
        derived_data = root / "DerivedData" / device.matrix_id
        command = [
            "xcodebuild",
            "-project", str(REPO / config["project"]),
            "-scheme", config["scheme"],
            "-configuration", "Debug",
            "-derivedDataPath", str(derived_data),
            "-destination", f"platform=iOS Simulator,id={device.udid}",
            "-parallel-testing-enabled", "NO",
            "-resultBundlePath", str(result_bundle),
        ]
        for selector in selectors_for_suite(config, suite):
            command.extend(["-only-testing:" + selector])
        command.append("test")
        # Inject per-unit paths directly into the XCTest runner. A shared
        # /tmp/shot_dir control file makes different simulators overwrite one
        # another when the matrix runs concurrently.
        manifest = str((REPO / config["manifest"]).resolve())
        test_env = os.environ.copy()
        test_env.update({
            "V50_SHOT_DIR": str(screenshots),
            "TEST_RUNNER_V50_SHOT_DIR": str(screenshots),
            "V50_EXPECTED_SHOT_MANIFEST": manifest,
            "TEST_RUNNER_V50_EXPECTED_SHOT_MANIFEST": manifest,
        })
        summary["test_environment"] = {
            "V50_SHOT_DIR": str(screenshots),
            "V50_EXPECTED_SHOT_MANIFEST": manifest,
        }
        completed = run(command, log=leaf / "xcodebuild.json", env=test_env)
        summary["xcodebuild_exit_code"] = completed.returncode
        summary["command"] = command
        image_audit = audit_images(config, screenshots, suite)
        summary["image_audit"] = image_audit
        if completed.returncode == 0 and image_audit["status"] == "passed":
            summary["status"] = "passed"
        else:
            summary["failure"] = "xcodebuild or image audit failed"
    except Exception as error:
        summary["failure"] = str(error)
        summary["image_audit"] = audit_images(config, screenshots, suite)
    summary["finished_at"] = utc_now()
    prior.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return summary


def unit_key(item: dict[str, Any]) -> tuple[str, str, str, str, str]:
    device = item["device"]
    return (
        device["matrix_id"],
        device["runtime_version"],
        item["appearance"],
        item["state"],
        item["suite"],
    )


def write_overall_summary(root: Path, summaries: list[dict[str, Any]]) -> None:
    summary_path = root / "summary.json"
    merged: dict[tuple[str, str, str, str, str], dict[str, Any]] = {}
    if summary_path.exists():
        try:
            previous = json.loads(summary_path.read_text(encoding="utf-8"))
            merged.update((unit_key(item), item) for item in previous.get("units", []))
        except (json.JSONDecodeError, KeyError, TypeError):
            pass
    merged.update((unit_key(item), item) for item in summaries)
    all_summaries = [merged[key] for key in sorted(merged)]
    payload = {
        "generated_at": utc_now(),
        "status": "passed" if all_summaries and all(item.get("status") == "passed" for item in all_summaries) else "failed",
        "units": all_summaries,
    }
    summary_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# v51 模拟器矩阵摘要",
        "",
        f"> 生成时间：{payload['generated_at']}；整体：**{payload['status']}**。",
        "",
        "| Device | Runtime | Appearance | State | Suite | XCTest | Images | Result |",
        "|---|---|---|---|---|---:|---:|---|",
    ]
    for item in all_summaries:
        device = item["device"]
        lines.append(
            f"| {device['matrix_id']} {device['name']} | iOS {device['runtime_version']} | "
            f"{item['appearance']} | {item['state']} | {item['suite']} | "
            f"{item.get('xcodebuild_exit_code', '—')} | {item.get('image_audit', {}).get('count', 0)} | "
            f"{item['status']} |"
        )
    (root / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def selected(values: str, available: list[str]) -> list[str]:
    if values == "all":
        return available
    requested = [item.strip() for item in values.split(",") if item.strip()]
    unknown = sorted(set(requested) - set(available))
    if unknown:
        raise ValueError("unknown values: " + ", ".join(unknown))
    return requested


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("discover")
    plan_parser = subparsers.add_parser("plan")
    run_parser = subparsers.add_parser("run")
    for target in (plan_parser, run_parser):
        target.add_argument("--devices", default="A3")
        target.add_argument("--appearances", default="light", choices=["light", "dark", "light,dark"])
        target.add_argument("--states", default="standard")
        target.add_argument("--suites", default="contract")
    run_parser.add_argument("--resume", action="store_true")
    run_parser.add_argument("--fail-fast", action="store_true")
    run_parser.add_argument("--content-size")
    run_parser.add_argument(
        "--project",
        help="override config project path (for example QiuJiV50.xcodeproj)",
    )
    run_parser.add_argument(
        "--workers",
        type=int,
        default=1,
        help="run units concurrently; each worker must target a distinct simulator UDID",
    )
    args = parser.parse_args()

    config = load_config(args.config.resolve())
    if args.command == "run" and args.project:
        config["project"] = args.project
    fingerprint = source_fingerprint(args.config.resolve())
    devices = resolve_devices(config)
    root = artifact_root(config)
    root.mkdir(parents=True, exist_ok=True)
    (root / "resolved-devices.json").write_text(
        json.dumps([item.as_dict() for item in devices], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if args.command == "discover":
        print(json.dumps([item.as_dict() for item in devices], ensure_ascii=False, indent=2))
        return 0

    by_id = {item.matrix_id: item for item in devices}
    device_ids = selected(args.devices, list(by_id))
    appearances = args.appearances.split(",")
    states = [item.strip() for item in args.states.split(",") if item.strip()]
    suites = selected(args.suites, list(config["suites"]))
    units = [
        (by_id[device_id], appearance, state, suite)
        for device_id in device_ids
        for appearance in appearances
        for state in states
        for suite in suites
    ]
    if args.command == "plan":
        print(json.dumps([
            {
                "device": device.as_dict(),
                "appearance": appearance,
                "state": state,
                "suite": suite,
                "artifact_directory": str(unit_directory(root, device, appearance, state, suite)),
                "selectors": selectors_for_suite(config, suite),
                "source_fingerprint": fingerprint,
            }
            for device, appearance, state, suite in units
        ], ensure_ascii=False, indent=2))
        return 0

    if args.workers < 1:
        parser.error("--workers must be at least 1")
    if args.workers > 1:
        unit_udids = [device.udid for device, _, _, _ in units]
        if len(unit_udids) != len(set(unit_udids)):
            parser.error("concurrent units must use distinct simulator UDIDs")

    def execute(unit: tuple[ResolvedDevice, str, str, str]) -> dict[str, Any]:
        device, appearance, state, suite = unit
        print(f"[{utc_now()}] START {device.matrix_id} iOS {device.runtime_version} {appearance} {state} {suite}", flush=True)
        summary = run_unit(
            config, device, appearance, state, suite,
            resume=args.resume,
            content_size=args.content_size,
            fingerprint=fingerprint,
        )
        print(f"[{utc_now()}] {summary['status'].upper()} {device.matrix_id} {appearance} {state} {suite}", flush=True)
        return summary

    summaries: list[dict[str, Any]] = []
    if args.workers == 1:
        for unit in units:
            summary = execute(unit)
            summaries.append(summary)
            write_overall_summary(root, summaries)
            if args.fail_fast and summary["status"] != "passed":
                break
    else:
        with ThreadPoolExecutor(max_workers=min(args.workers, len(units))) as executor:
            futures = {executor.submit(execute, unit): unit for unit in units}
            for future in as_completed(futures):
                summary = future.result()
                summaries.append(summary)
                write_overall_summary(root, summaries)
                if args.fail_fast and summary["status"] != "passed":
                    for pending in futures:
                        pending.cancel()
    return 0 if summaries and all(item["status"] == "passed" for item in summaries) else 1


if __name__ == "__main__":
    raise SystemExit(main())

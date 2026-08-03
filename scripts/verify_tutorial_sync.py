#!/usr/bin/env python3
"""
verify_tutorial_sync.py — 精讲资产全链路同步校验

链路：序列 JSON → 出片产物 → 回填图 → 精讲 image 引用 → 精讲结构

四项检查：
  C1 出片新鲜度  build/position_play_export/<seq>/ 是否不早于 content/.../<seq>.json
  C2 回填一致性  产物图与 DrillTutorials 同名文件内容是否一致（md5）
  C3 引用指向    精讲 image 是否命中最新图（识别 `X.png` 旧图 vs `X_still.png` 新图）
  C4 结构对齐    精讲逐杆节数 / 球形数是否与最新序列一致

用法：
  python3 scripts/verify_tutorial_sync.py
  python3 scripts/verify_tutorial_sync.py --only C3 C4
  python3 scripts/verify_tutorial_sync.py --json

退出码：任一 FAIL 则为 1，否则 0。WARN 不影响退出码。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_tutorial_images import collect_image_refs  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[1]
DRILLS_DIR = REPO_ROOT / "QiuJi" / "Resources" / "Drills"
TUTORIALS_ROOT = REPO_ROOT / "QiuJi" / "Resources" / "DrillTutorials"
SEQUENCES_DIR = REPO_ROOT / "content" / "position_play" / "sequences"
EXPORT_DIR = REPO_ROOT / "build" / "position_play_export"

# 出片产物中不参与回填的项（卡片素材，另有用途）。
NON_BACKFILL_STEMS = {"cover"}
# 内容可比对的扩展名；W4 转码为 HEIC 后无法按字节比对，降级为存在性检查。
BYTEWISE_SUFFIXES = {".png"}
MANUAL01_TOKEN = "manual01"
STILL_STEP_RE = re.compile(r"^(s\d{2})_still$")

SEQ_NAME_RE = re.compile(r"^(drill_c\d+)__")
FORMATION_RE = re.compile(r"球形(\d+)-(\d+)杆")
SHOTS_RE = re.compile(r"-(\d+)杆$")
SHOT_SECTION_RE = re.compile(r"^第.+杆")


def still_dest_stem(src_stem: str) -> str:
    """与 import-engine-export-to-app.py 一致：sNN_still → sNN。"""
    match = STILL_STEP_RE.fullmatch(src_stem)
    if match:
        return match.group(1)
    if src_stem.endswith("_still"):
        return src_stem[: -len("_still")]
    return src_stem


def parse_export_dir(name: str) -> tuple[str, str] | None:
    """与 import-engine-export-to-app.py 一致：返回 (drill_id, token)。"""
    if name.startswith("seq_"):
        return None
    match = re.match(r"^(drill_c\d{3})(?:__([^-]+))?(?:-.*)?$", name)
    if not match:
        return None
    token = re.sub(r"[^\w.\-]+", "_", match.group(2) or "main", flags=re.UNICODE)
    return match.group(1), token


def md5(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_sequences() -> dict[str, list[dict]]:
    """按 drill id 归集最新序列：{drill_id: [{formation, shots, stem, path}, ...]}。"""
    result: dict[str, list[dict]] = defaultdict(list)
    if not SEQUENCES_DIR.is_dir():
        return result
    for path in sorted(SEQUENCES_DIR.glob("*.json")):
        match = SEQ_NAME_RE.match(path.name)
        if not match:
            continue  # seq_* 试录序列不属任何 drill
        stem = path.stem
        formation_match = FORMATION_RE.search(stem)
        if formation_match:
            formation = int(formation_match.group(1))
            shots = int(formation_match.group(2))
        else:
            shots_match = SHOTS_RE.search(stem)
            formation = 1
            shots = int(shots_match.group(1)) if shots_match else -1
        result[match.group(1)].append(
            {"formation": formation, "shots": shots, "stem": stem, "path": path}
        )
    for items in result.values():
        items.sort(key=lambda item: item["formation"])
    return result


def load_tutorials() -> dict[str, dict]:
    """按 drill id 归集精讲结构：{drill_id: {shots_per_formation, has_formations}}。"""
    result: dict[str, dict] = {}
    for path in sorted(DRILLS_DIR.rglob("*.json")):
        if path.name == "index.json":
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        tutorial = data.get("tutorial")
        if not isinstance(tutorial, dict):
            continue
        drill_id = data.get("id") or path.stem

        def count_shots(sections) -> int:
            return sum(
                1
                for section in (sections or [])
                if isinstance(section, dict)
                and SHOT_SECTION_RE.match(str(section.get("title", "")))
            )

        formations = tutorial.get("formations")
        if isinstance(formations, list) and formations:
            shots = [count_shots(form.get("sections")) for form in formations]
            has_formations = True
        else:
            shots = [count_shots(tutorial.get("sections"))]
            has_formations = False
        result[drill_id] = {"shots": shots, "has_formations": has_formations}
    return result


def check_export_freshness(sequences: dict[str, list[dict]]) -> dict:
    """C1：出片产物不得早于其序列 JSON。"""
    stale, missing, ok = [], [], 0
    for drill_id, items in sorted(sequences.items()):
        for item in items:
            if item["shots"] == 0:
                continue  # 0 杆球形仅供试打摆球，出片 runner 本就跳过
            marker = EXPORT_DIR / item["stem"] / "initial.png"
            if not marker.exists():
                missing.append((drill_id, item["stem"]))
                continue
            if marker.stat().st_mtime < item["path"].stat().st_mtime:
                stale.append((drill_id, item["stem"]))
            else:
                ok += 1
    return {"ok": ok, "fail": stale, "warn": missing}


def check_backfill(referenced: set[str]) -> dict:
    """C2：出片产物与 DrillTutorials 回填图内容一致。

    落位规则与 `import-engine-export-to-app.py` 对齐（D-v25-6）：
    `sNN_still.png` → `<drillId>_sNN.png`；多球形带 token 前缀；
    `manual01` 额外写无前缀别名。冲突仅在「被精讲引用」时判失败。
    """
    if not EXPORT_DIR.is_dir():
        return {"ok": 0, "fail": [], "collision": [], "collision_idle": [], "warn": [],
                "not_backfilled": []}
    on_disk = {p.name: p for p in TUTORIALS_ROOT.iterdir() if p.is_file()}

    # 先按 drill 分组，才能知道是否 multi（与回填脚本一致）。
    by_drill: dict[str, list[tuple[str, Path]]] = defaultdict(list)
    for export_sub in sorted(EXPORT_DIR.iterdir()):
        if not export_sub.is_dir() or export_sub.name.startswith("."):
            continue
        parsed = parse_export_dir(export_sub.name)
        if parsed is None or not (export_sub / "full.mp4").is_file():
            continue
        drill_id, token = parsed
        by_drill[drill_id].append((token, export_sub))

    target_sources: dict[str, list[str]] = defaultdict(list)
    pairs: list[tuple[str, Path, Path]] = []
    expected: set[str] = set()

    for drill_id, variants in by_drill.items():
        multi = len(variants) > 1
        for token, export_sub in variants:
            still_prefix = f"{drill_id}_{token}_" if multi else f"{drill_id}_"
            write_alias = token == MANUAL01_TOKEN
            for png in sorted(export_sub.glob("*.png")):
                if png.stem in NON_BACKFILL_STEMS:
                    continue
                dest_stem = still_dest_stem(png.stem)
                primary = f"{still_prefix}{dest_stem}.png"
                expected.add(primary)
                target_sources[primary].append(export_sub.name)
                if primary in on_disk:
                    pairs.append((primary, png, on_disk[primary]))
                if write_alias and multi:
                    alias = f"{drill_id}_{dest_stem}.png"
                    expected.add(alias)
                    target_sources[alias].append(export_sub.name)
                    if alias in on_disk:
                        pairs.append((alias, png, on_disk[alias]))

    collision, collision_idle = [], []
    for name, sources in sorted(target_sources.items()):
        # 同一 export 既写 primary 又写 alias 不算冲突；不同 export 争抢同名才算。
        unique_sources = sorted(set(sources))
        if len(unique_sources) <= 1:
            continue
        bucket = collision if Path(name).stem in referenced else collision_idle
        bucket.append((name, unique_sources))
    colliding_names = {name for name, _ in collision + collision_idle}

    ok, fail, warn = 0, [], []
    hash_cache: dict[Path, str] = {}
    seen_pair: set[tuple[str, str]] = set()
    for target_name, source, target in pairs:
        key = (target_name, str(source))
        if key in seen_pair:
            continue
        seen_pair.add(key)
        if target_name in colliding_names:
            continue
        if target.suffix.lower() not in BYTEWISE_SUFFIXES:
            warn.append((target_name, "非 PNG，跳过字节比对"))
            continue
        if target not in hash_cache:
            hash_cache[target] = md5(target)
        if md5(source) == hash_cache[target]:
            ok += 1
        else:
            fail.append((target_name, source.parent.name))

    backfilled = {name for name, _, _ in pairs}
    not_backfilled = sorted(expected - backfilled)
    return {"ok": ok, "fail": fail, "collision": collision,
            "collision_idle": collision_idle, "warn": warn,
            "not_backfilled": not_backfilled}


def check_refs() -> dict:
    """C3：精讲 image 引用是否命中最新图（而非同名旧图）。"""
    on_disk = {p.name: p for p in TUTORIALS_ROOT.iterdir() if p.is_file()}
    stale, dead, ok = [], [], 0
    for drill_id, image, hint in collect_image_refs():
        candidates = [image, f"{image}.png", f"{image}.heic", f"{image}.jpg", f"{image}.jpeg"]
        hit = next((on_disk[name] for name in candidates if name in on_disk), None)
        if hit is None:
            dead.append((drill_id, image, hint))
            continue
        newer = on_disk.get(f"{image}_still.png")
        if newer is not None and hit.stat().st_mtime < newer.stat().st_mtime:
            stale.append((drill_id, image, hint))
        else:
            ok += 1
    return {"ok": ok, "fail": stale, "warn": dead}


def check_structure(sequences: dict[str, list[dict]], tutorials: dict[str, dict]) -> dict:
    """C4：精讲逐杆节数 / 球形数与最新序列一致。"""
    ok, fail, warn = 0, [], []
    for drill_id, tutorial in sorted(tutorials.items()):
        seq = [item for item in sequences.get(drill_id, []) if item["shots"] > 0]
        if not seq:
            warn.append((drill_id, "无序列", "—"))
            continue
        shots = tutorial["shots"]
        if sum(shots) == 0:
            warn.append((drill_id, "legacy 无逐杆节，待迁移",
                         "/".join(str(item["shots"]) for item in seq)))
            continue
        expected = [item["shots"] for item in seq]
        if shots == expected:
            ok += 1
        else:
            fail.append((drill_id, "/".join(map(str, shots)), "/".join(map(str, expected))))
    return {"ok": ok, "fail": fail, "warn": warn}


def group_by_drill(names) -> list[tuple[str, int]]:
    counts: dict[str, int] = defaultdict(int)
    for name in names:
        match = re.match(r"(drill_c\d+)_", name)
        counts[match.group(1) if match else name] += 1
    return sorted(counts.items())


def render_report(results: dict) -> None:
    if "C1" in results:
        r = results["C1"]
        print(f"\n[C1] 出片新鲜度  通过 {r['ok']}  失败 {len(r['fail'])}  提示 {len(r['warn'])}")
        for drill_id, stem in r["fail"]:
            print(f"  ✗ {drill_id}  产物早于序列 JSON，需重出片：{stem}")
        for drill_id, stem in r["warn"]:
            print(f"  · {drill_id}  尚无出片产物：{stem}")

    if "C2" in results:
        r = results["C2"]
        print(f"\n[C2] 回填一致性  通过 {r['ok']}  内容不符 {len(r['fail'])}  "
              f"冲突(已被引用) {len(r['collision'])}  冲突(未引用) {len(r['collision_idle'])}  "
              f"未回填 {len(r['not_backfilled'])}")
        for name, source in r["fail"]:
            print(f"  ✗ {name}  内容与当前产物不一致（源 {source}）")
        for label, items, mark in (("✗", r["collision"], "被引用"),
                                   ("·", r["collision_idle"], "未引用")):
            grouped = group_by_drill(name for name, _ in items)
            for drill_id, count in grouped:
                print(f"  {label} {drill_id}  {count} 张图被多个球形产物争抢同名（{mark}）")

    if "C3" in results:
        r = results["C3"]
        print(f"\n[C3] 引用指向  通过 {r['ok']}  命中旧图 {len(r['fail'])}  失效 {len(r['warn'])}")
        for drill_id, image, hint in r["fail"]:
            print(f"  ✗ {drill_id}  {image} 命中旧图，存在更新的 {image}_still  @ {hint}")
        by_drill: dict[str, int] = defaultdict(int)
        for drill_id, _, _ in r["warn"]:
            by_drill[drill_id] += 1
        for drill_id, count in sorted(by_drill.items()):
            print(f"  · {drill_id}  {count} 处引用无对应文件")

    if "C4" in results:
        r = results["C4"]
        print(f"\n[C4] 结构对齐  通过 {r['ok']}  不一致 {len(r['fail'])}  待迁移/无序列 {len(r['warn'])}")
        for drill_id, actual, expected in r["fail"]:
            print(f"  ✗ {drill_id}  精讲 {actual} 杆 vs 最新序列 {expected} 杆")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", nargs="+", choices=["C1", "C2", "C3", "C4"],
                        help="只跑指定检查（默认全跑）")
    parser.add_argument("--json", action="store_true", help="输出机器可读摘要")
    args = parser.parse_args()

    selected = set(args.only or ["C1", "C2", "C3", "C4"])
    sequences = load_sequences()
    tutorials = load_tutorials()

    results: dict[str, dict] = {}
    if "C1" in selected:
        results["C1"] = check_export_freshness(sequences)
    if "C2" in selected:
        referenced = {image for _, image, _ in collect_image_refs()}
        results["C2"] = check_backfill(referenced)
    if "C3" in selected:
        results["C3"] = check_refs()
    if "C4" in selected:
        results["C4"] = check_structure(sequences, tutorials)

    failures = sum(
        len(r.get("fail", [])) + len(r.get("collision", [])) for r in results.values()
    )

    if args.json:
        print(json.dumps({"failures": failures, "checks": results},
                         ensure_ascii=False, indent=2, default=str))
    else:
        render_report(results)
        print(f"\n{'=' * 60}")
        print(f"总计 FAIL: {failures}" if failures else "总计 FAIL: 0 —— 全链路同步")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())

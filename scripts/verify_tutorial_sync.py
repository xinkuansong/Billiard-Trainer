#!/usr/bin/env python3
"""
verify_tutorial_sync.py — 内容不变量校验（契约 .kiro/steering/content-data-contract.md §7）

链路：序列 JSON → 出片产物 → 回填图 → 精讲 image 引用 → 精讲结构 → Bundle 派生物

同步链路四项（I1–I4）：
  C1 出片新鲜度  build/position_play_export/<seq>/ 是否不早于 content/.../<seq>.json   [I2]
  C2 回填一致性  产物图与 DrillTutorials 同名文件内容是否一致（md5）                   [I3]
  C3 引用指向    精讲 image 是否命中最新图；失效引用数不得超过基线                      [I4]
  C4 结构对齐    精讲逐杆节数 / 球形数是否与最新序列一致                                [I1]

不变量四项（v29 W9 新增）：
  I5 精讲球形 token ⊆ 序列 token 集合（token 由 image 文件名反解）
  I7 profile formation 集合 == 序列 token 集合，或 profile 已标记退役
  I8 Bundle/DrillBoards ⊆ content/.../sequences 的 drill_c*.json（名字 + 字节）
  I9 index.json 登记的 drill 至少有 1 条序列，或在豁免名单内

基线与已知豁免真源：scripts/content_invariant_baselines.json（棘轮，只许收紧）。

用法：
  python3 scripts/verify_tutorial_sync.py                 # 全部检查（含 C4）
  python3 scripts/verify_tutorial_sync.py --gate          # 门禁模式（pre-push；与默认相同阻塞集，见 GATE_EXEMPT_CHECKS）
  python3 scripts/verify_tutorial_sync.py --only C3 I5
  python3 scripts/verify_tutorial_sync.py --json
  python3 scripts/verify_tutorial_sync.py --root <fixture> --baselines <json>

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
DEFAULT_BASELINES = Path(__file__).resolve().parent / "content_invariant_baselines.json"

CHECK_IDS = ["C1", "C2", "C3", "C4", "I5", "I7", "I8", "I9"]
# 门禁模式下不计入退出码的检查（已知豁免）。v26 W13：C4 已转正为阻塞，集合为空。
GATE_EXEMPT_CHECKS: set[str] = set()
# 计入 FAIL 的结果键；warn / *_idle / exempt 等一律不计。
FAIL_KEYS = ("fail", "collision", "breach")


class Paths:
    """全部内容目录锚在同一个 root，便于用 fixture 副本做构造性用例。"""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.drills = root / "QiuJi" / "Resources" / "Drills"
        self.tutorials = root / "QiuJi" / "Resources" / "DrillTutorials"
        self.sequences = root / "content" / "position_play" / "sequences"
        self.export = root / "build" / "position_play_export"
        self.boards = root / "QiuJi" / "Resources" / "DrillBoards"
        self.profiles = root / "content" / "drill_profiles"


DEFAULT_PATHS = Paths(REPO_ROOT)

# 兼容既有调用方（generate_tutorial_ledger.py 直接 import 这些常量）。
DRILLS_DIR = DEFAULT_PATHS.drills
TUTORIALS_ROOT = DEFAULT_PATHS.tutorials
SEQUENCES_DIR = DEFAULT_PATHS.sequences
EXPORT_DIR = DEFAULT_PATHS.export


def load_baselines(path: Path | None = None) -> dict:
    path = path or DEFAULT_BASELINES
    if not path.is_file():
        raise SystemExit(f"基线文件缺失：{path}")
    return json.loads(path.read_text(encoding="utf-8"))

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


def sequence_token(name: str) -> str:
    """与 DrillTryoutBoardStore.token(fromFileName:drillId:) 一致：`__` 与下一个 `-` 之间。

    旧式单序列（无 `__`）为空串。
    """
    match = re.match(r"^drill_c\d+__([^-]*)-", name)
    return match.group(1) if match else ""


def load_sequences(paths: Paths | None = None) -> dict[str, list[dict]]:
    """按 drill id 归集最新序列：{drill_id: [{formation, shots, stem, path}, ...]}。"""
    paths = paths or DEFAULT_PATHS
    result: dict[str, list[dict]] = defaultdict(list)
    if not paths.sequences.is_dir():
        return result
    for path in sorted(paths.sequences.glob("*.json")):
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
            {"formation": formation, "shots": shots, "stem": stem, "path": path,
             "token": sequence_token(path.name)}
        )
    for items in result.values():
        items.sort(key=lambda item: item["formation"])
    return result


def load_tutorials(paths: Paths | None = None) -> dict[str, dict]:
    """按 drill id 归集精讲结构：{drill_id: {shots_per_formation, has_formations}}。"""
    paths = paths or DEFAULT_PATHS
    result: dict[str, dict] = {}
    for path in sorted(paths.drills.rglob("*.json")):
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


def check_export_freshness(sequences: dict[str, list[dict]],
                           paths: Paths | None = None) -> dict:
    """C1：出片产物不得早于其序列 JSON。"""
    paths = paths or DEFAULT_PATHS
    stale, missing, ok = [], [], 0
    for drill_id, items in sorted(sequences.items()):
        for item in items:
            if item["shots"] == 0:
                continue  # 0 杆球形仅供试打摆球，出片 runner 本就跳过
            marker = paths.export / item["stem"] / "initial.png"
            if not marker.exists():
                missing.append((drill_id, item["stem"]))
                continue
            if marker.stat().st_mtime < item["path"].stat().st_mtime:
                stale.append((drill_id, item["stem"]))
            else:
                ok += 1
    return {"ok": ok, "fail": stale, "warn": missing}


def check_backfill(referenced: set[str], paths: Paths | None = None) -> dict:
    """C2：出片产物与 DrillTutorials 回填图内容一致。

    落位规则与 `import-engine-export-to-app.py` 对齐（D-v25-6）：
    `sNN_still.png` → `<drillId>_sNN.png`；多球形带 token 前缀；
    `manual01` 额外写无前缀别名。冲突仅在「被精讲引用」时判失败。
    """
    paths = paths or DEFAULT_PATHS
    if not paths.export.is_dir():
        return {"ok": 0, "fail": [], "collision": [], "collision_idle": [], "warn": [],
                "not_backfilled": []}
    on_disk = {p.name: p for p in paths.tutorials.iterdir() if p.is_file()}

    # 先按 drill 分组，才能知道是否 multi（与回填脚本一致）。
    by_drill: dict[str, list[tuple[str, Path]]] = defaultdict(list)
    for export_sub in sorted(paths.export.iterdir()):
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


def check_refs(paths: Paths | None = None, dead_baseline: int | None = None) -> dict:
    """C3：精讲 image 引用是否命中最新图（而非同名旧图）。

    失效引用（dead）本身是 WARN——legacy 命名的历史债，重出片物理上生不出这些文件。
    但它必须**只许减不许增**：给了 `dead_baseline` 时，超出基线的部分计为 FAIL（棘轮）。
    """
    paths = paths or DEFAULT_PATHS
    on_disk = {p.name: p for p in paths.tutorials.iterdir() if p.is_file()}
    stale, dead, ok = [], [], 0
    for drill_id, image, hint in collect_image_refs(paths.drills):
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
    breach = []
    if dead_baseline is not None and len(dead) > dead_baseline:
        breach.append((f"失效引用 {len(dead)} 处 > 基线 {dead_baseline} 处",
                       "新增失效引用；修好或按契约 §8 走豁免登记后再上调基线"))
    return {"ok": ok, "fail": stale, "warn": dead, "breach": breach,
            "dead_baseline": dead_baseline}


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


STEP_MARKER_RE = re.compile(r"^(initial|final|cover|s\d{2,})$")


def claimed_token(drill_id: str, image: str) -> str | None:
    """从精讲 image 文件名反解它声称的球形 token。

    产物命名（`import-engine-export-to-app.py`）：多球形 `<drillId>_<token>_<step>`，
    单球形 `<drillId>_<step>`，`manual01` 额外写无前缀别名。历史上还存在 legacy 的
    `<drillId>_fN_<step>` 与 `<drillId>_<step>_fN` 两种写法（契约 §8.15）。
    故：剥掉 drillId 前缀后，去掉 step 标记段，余下即声称的 token（无则空串）。
    返回 None 表示无法归因到该 drill（不做判定）。
    """
    if not image.startswith(f"{drill_id}_"):
        return None
    segments = image[len(drill_id) + 1:].split("_")
    rest = [seg for seg in segments if not STEP_MARKER_RE.match(seg)]
    return "_".join(rest)


def check_tutorial_tokens(sequences: dict[str, list[dict]], exempt: dict[str, list[str]],
                          paths: Paths | None = None) -> dict:
    """I5：精讲声称的球形 token ⊆ 该 drill 的序列 token 集合。

    空 token（无前缀写法）合法的条件：该 drill 只有 1 条序列（回填本就不加前缀），
    或含 `manual01`（回填会额外写无前缀别名）。

    豁免钉到具体 token（契约 §8.15）：清单内的 legacy token 记为已知豁免，
    同一 drill 出现清单之外的新坏 token 仍然 FAIL。
    """
    paths = paths or DEFAULT_PATHS
    claims: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))
    for drill_id, image, hint in collect_image_refs(paths.drills):
        token = claimed_token(drill_id, image)
        if token is None:
            continue
        claims[drill_id][token].append(hint)

    ok, fail, exempted, warn = 0, [], [], []
    for drill_id, tokens in sorted(claims.items()):
        seq_items = sequences.get(drill_id) or []
        if not seq_items:
            warn.append((drill_id, "无序列，无法判定 token", "—"))
            continue
        seq_tokens = {item["token"] for item in seq_items}
        allowed = set(seq_tokens)
        if len(seq_items) == 1 or MANUAL01_TOKEN in seq_tokens:
            allowed.add("")
        bad = sorted(token for token in tokens if token not in allowed)
        allowed_legacy = set(exempt.get(drill_id) or [])
        unexpected = [token for token in bad if token not in allowed_legacy]
        if not bad:
            if drill_id in exempt:
                warn.append((drill_id, "豁免已可解除（token 现已全部对齐）",
                             "请从 content_invariant_baselines.json 的 i5_legacy_token_exempt 删除"))
            else:
                ok += 1
            continue
        seq_desc = "/".join(sorted(seq_tokens))
        if unexpected:
            fail.append((drill_id, "/".join(repr(token) for token in unexpected), seq_desc))
        else:
            exempted.append((drill_id, "/".join(repr(token) for token in bad), seq_desc))
    return {"ok": ok, "fail": fail, "exempt": exempted, "warn": warn}


def profile_retired(data: dict) -> bool:
    """profile 是否已按契约 §1.1 推论 1 标记为退役设计档案。"""
    if data.get("retired") is True:
        return True
    return str(data.get("status", "")).strip().lower() in {"retired", "deprecated"}


def check_profiles(sequences: dict[str, list[dict]], exempt: dict[str, list[str]],
                   paths: Paths | None = None) -> dict:
    """I7：profile formation 集合 == 序列 token 集合，或 profile 已标记退役。

    豁免钉到具体 formation id 集合（契约 §8.1）：profile 被改成别的不一致集合仍然 FAIL。
    """
    paths = paths or DEFAULT_PATHS
    ok, fail, exempted, warn = 0, [], [], []
    if not paths.profiles.is_dir():
        return {"ok": 0, "fail": [], "exempt": [], "warn": [("—", "profile 目录不存在", "—")]}
    for path in sorted(paths.profiles.glob("*.profile.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        drill_id = data.get("drillId") or path.name.split(".")[0]
        profile_ids = {str(form.get("id")) for form in (data.get("formations") or [])
                       if isinstance(form, dict)}
        seq_tokens = {item["token"] for item in (sequences.get(drill_id) or [])}
        if profile_ids == seq_tokens:
            if drill_id in exempt:
                warn.append((drill_id, "豁免已可解除（profile 已与序列一致）",
                             "请从 i7_stale_profile_exempt 删除"))
            else:
                ok += 1
            continue
        if profile_retired(data):
            warn.append((drill_id, "已标记退役，跳过一致性判定", "—"))
            continue
        detail = (drill_id,
                  "/".join(sorted(profile_ids)) or "—",
                  "/".join(sorted(seq_tokens)) or "—")
        registered = set(exempt.get(drill_id) or [])
        (exempted if registered == profile_ids else fail).append(detail)
    return {"ok": ok, "fail": fail, "exempt": exempted, "warn": warn}


def check_boards(paths: Paths | None = None) -> dict:
    """I8：Bundle/DrillBoards 是上游序列 drill_c*.json 的子集（名字 + 字节都得对上）。

    `make tryout-sync` 是 `rsync -a --delete`，故正确状态下必然字节相同；
    出现孤儿或字节不符 ⇒ 手改了产物目录（契约 §6.4 红线）或漏跑同步。
    """
    paths = paths or DEFAULT_PATHS
    if not paths.boards.is_dir():
        return {"ok": 0, "fail": [], "warn": [("—", "DrillBoards 目录不存在", "—")]}
    upstream = {p.name: p for p in paths.sequences.glob("drill_c*.json")}
    bundled = {p.name: p for p in paths.boards.glob("*.json")}
    fail, warn, ok = [], [], 0
    for name, board in sorted(bundled.items()):
        source = upstream.get(name)
        if source is None:
            fail.append((name, "Bundle 有、上游无（孤儿）", "跑 make tryout-sync 清理"))
            continue
        if md5(board) != md5(source):
            fail.append((name, "内容与上游序列不一致", "手改产物或漏跑 make tryout-sync"))
            continue
        ok += 1
    for name in sorted(set(upstream) - set(bundled)):
        warn.append((name, "上游有、Bundle 未同步", "跑 make tryout-sync"))
    return {"ok": ok, "fail": fail, "warn": warn}


def check_sequence_coverage(sequences: dict[str, list[dict]], exempt: list[str],
                            paths: Paths | None = None) -> dict:
    """I9：index.json 登记的每个 drill 至少 1 条序列，或在 §8.5 豁免名单内。"""
    paths = paths or DEFAULT_PATHS
    index_path = paths.drills / "index.json"
    if not index_path.is_file():
        return {"ok": 0, "fail": [], "exempt": [], "warn": [("—", "index.json 不存在", "—")]}
    index = json.loads(index_path.read_text(encoding="utf-8"))
    registered = [drill_id
                  for category in index.get("categories", [])
                  for drill_id in category.get("drills", [])]
    exempt_set = set(exempt)
    ok, fail, exempted, warn = 0, [], [], []
    for drill_id in registered:
        if sequences.get(drill_id):
            if drill_id in exempt_set:
                warn.append((drill_id, "豁免已可解除（已有序列）",
                             "请从 i9_no_sequence_exempt 删除"))
            else:
                ok += 1
            continue
        detail = (drill_id, "无任何序列", "录制序列或登记豁免（契约 §8.5）")
        (exempted if drill_id in exempt_set else fail).append(detail)
    for drill_id in sorted(set(sequences) - set(registered)):
        warn.append((drill_id, "有序列但未登记进 index.json", "—"))
    return {"ok": ok, "fail": fail, "exempt": exempted, "warn": warn}


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
        baseline = r.get("dead_baseline")
        suffix = f"（基线 {baseline}）" if baseline is not None else ""
        print(f"\n[C3] 引用指向  通过 {r['ok']}  命中旧图 {len(r['fail'])}  "
              f"失效 {len(r['warn'])}{suffix}")
        for drill_id, image, hint in r["fail"]:
            print(f"  ✗ {drill_id}  {image} 命中旧图，存在更新的 {image}_still  @ {hint}")
        for what, how in r.get("breach", []):
            print(f"  ✗ 基线被突破：{what} —— {how}")
        by_drill: dict[str, int] = defaultdict(int)
        for drill_id, _, _ in r["warn"]:
            by_drill[drill_id] += 1
        for drill_id, count in sorted(by_drill.items()):
            print(f"  · {drill_id}  {count} 处引用无对应文件")
        if baseline is not None and len(r["warn"]) < baseline:
            print(f"  · 失效引用已降到 {len(r['warn'])} < 基线 {baseline}，"
                  f"请把 c3_dead_refs_baseline 下调收紧棘轮")

    if "C4" in results:
        r = results["C4"]
        print(f"\n[C4] 结构对齐  通过 {r['ok']}  不一致 {len(r['fail'])}  待迁移/无序列 {len(r['warn'])}")
        for drill_id, actual, expected in r["fail"]:
            print(f"  ✗ {drill_id}  精讲 {actual} 杆 vs 最新序列 {expected} 杆")

    for check_id, title, columns in (
        ("I5", "精讲球形 token ⊆ 序列 token", ("精讲声称", "序列实际")),
        ("I7", "profile vs 序列 token", ("profile", "序列实际")),
        ("I8", "Bundle DrillBoards ⊆ 上游序列", None),
        ("I9", "登记 drill 至少 1 条序列", None),
    ):
        if check_id not in results:
            continue
        r = results[check_id]
        exempt = r.get("exempt", [])
        print(f"\n[{check_id}] {title}  通过 {r['ok']}  违规 {len(r['fail'])}  "
              f"已知豁免 {len(exempt)}  提示 {len(r['warn'])}")

        def line(mark: str, row: tuple[str, str, str], tail: str = "") -> None:
            left, mid, right = row
            body = (f"{columns[0]} {mid} vs {columns[1]} {right}" if columns
                    else f"{mid} —— {right}")
            print(f"  {mark} {left}  {body}{tail}")

        for row in r["fail"]:
            line("✗", row)
        for row in exempt:
            line("⊘", row, "（已知豁免）")
        for row in r["warn"]:
            line("·", row)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", nargs="+", choices=CHECK_IDS,
                        help="只跑指定检查（默认全跑）")
    parser.add_argument("--gate", action="store_true",
                        help="门禁模式（pre-push 入口；GATE_EXEMPT_CHECKS 内检查不计入退出码）")
    parser.add_argument("--json", action="store_true", help="输出机器可读摘要")
    parser.add_argument("--root", type=Path, default=REPO_ROOT,
                        help="内容根目录（默认仓库根；构造性用例可指向 fixture 副本）")
    parser.add_argument("--baselines", type=Path, default=DEFAULT_BASELINES,
                        help="基线与豁免名单文件")
    args = parser.parse_args()

    selected = set(args.only or CHECK_IDS)
    paths = Paths(args.root.resolve())
    baselines = load_baselines(args.baselines)
    sequences = load_sequences(paths)
    tutorials = load_tutorials(paths)

    results: dict[str, dict] = {}
    if "C1" in selected:
        results["C1"] = check_export_freshness(sequences, paths)
    if "C2" in selected:
        referenced = {image for _, image, _ in collect_image_refs(paths.drills)}
        results["C2"] = check_backfill(referenced, paths)
    if "C3" in selected:
        results["C3"] = check_refs(paths, baselines.get("c3_dead_refs_baseline"))
    if "C4" in selected:
        results["C4"] = check_structure(sequences, tutorials)
    if "I5" in selected:
        results["I5"] = check_tutorial_tokens(
            sequences, baselines.get("i5_legacy_token_exempt", []), paths)
    if "I7" in selected:
        results["I7"] = check_profiles(
            sequences, baselines.get("i7_stale_profile_exempt", []), paths)
    if "I8" in selected:
        results["I8"] = check_boards(paths)
    if "I9" in selected:
        results["I9"] = check_sequence_coverage(
            sequences, baselines.get("i9_no_sequence_exempt", []), paths)

    blocking = {cid: r for cid, r in results.items()
                if not (args.gate and cid in GATE_EXEMPT_CHECKS)}
    failures = sum(len(r.get(key, [])) for r in blocking.values() for key in FAIL_KEYS)
    exempted_failures = sum(
        len(r.get(key, []))
        for cid, r in results.items() if cid not in blocking
        for key in FAIL_KEYS
    )

    if args.json:
        print(json.dumps({"failures": failures, "gate": args.gate,
                          "exempted_failures": exempted_failures, "checks": results},
                         ensure_ascii=False, indent=2, default=str))
    else:
        render_report(results)
        print(f"\n{'=' * 60}")
        if args.gate:
            print(f"门禁模式（阻塞项：{'/'.join(cid for cid in CHECK_IDS if cid in blocking)}）")
            if exempted_failures:
                print(f"已知豁免不计入：{'/'.join(sorted(GATE_EXEMPT_CHECKS))} "
                      f"共 {exempted_failures} 项（解除条件见契约 §7/§8）")
        print(f"总计 FAIL: {failures}" if failures else "总计 FAIL: 0 —— 全链路同步")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())

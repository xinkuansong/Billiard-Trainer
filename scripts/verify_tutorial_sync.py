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

模型可解码性（v30 X-1 新增）：
  I10 全部 bundled drill JSON 能被 App 的 Codable 模型解码（必填字段齐全、类型正确）

剂量与计划绑定（v31 W4 新增，契约 §5.6 / §6.6）：
  I6a 有序列 drill 的 `sets.perFormation` token 集合 == 该 drill 的序列 token 集合
  I6b `mode == sequence` 的球形 `ballsPerRound` == 该球形序列的实测杆数（len(steps)）
  I11 官方计划可解析：drillId ∈ index.json、dose 结构可解析、按球形引用的 token
      ∈ 该 drill 的 perFormation token 集合 ∩ 序列 token 集合
  I12 六轴 load 齐全、值域 0–4；有 perFormation 时每球形必有 load，drill 级 load
      = 代表球形实分；无 perFormation 时只允许 drill 级 load（契约 §5.7 / §7）
  I13 排课规则：focused 首次引入不得早于语义课表建议周、热身≤主课（scalar；
      reviewFrom 咬合热身豁免）、衰减剂量单调不增且减量须标 decay、reviewFrom 外键有效、
      focused 首次引入序对照 W0 主课表（只比序，不比建议周）

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

CHECK_IDS = ["C1", "C2", "C3", "C4", "I5", "I6a", "I6b", "I7", "I8", "I9", "I10", "I11", "I12", "I13"]
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
        self.plans = root / "QiuJi" / "Resources" / "Plans"
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


# ── I6a / I6b / I11：剂量口径与计划绑定（v31 W4 落地；v34 W0 改形状约束）────
#
# 结构性豁免（**规则判定，不入基线**，契约 §5.6.2 / §5.6.4）：
#   · 无任何序列的 drill —— 人工定量，可不写 `perFormation`，I6a/I6b 均不适用；
#   · 空序列（0 杆）球形 —— 人工定量，形状约束不适用；
#   · `mode == repetition` 的球形 —— 序列仅作示范，几何锁死（bpr==杆数）不适用，
#     但受 **形状约束**（阻塞级，v34 R13）：`ballsPerRound ∈ [8,15]`（默认 15，
#     非 15 须 `doseNote`）且 `defaultRounds == 序列实测杆数`（轮 = 位置，全覆盖；
#     例外须 `doseNote`）。
# 棘轮豁免（钉到 drillId/token，入 `content_invariant_baselines.json`）：
#   · `i6a_token_mismatch_exempt` / `i6b_shots_exempt` —— 目前均为空。
#     新增豁免必须先在契约 §8 登记解除条件；清单只许缩短。
#
# 总量护栏（旧 §5.6.3 D13，40–60 球）已于 v34 W0 **作废**（契约 D18）：
# 剂量数值真源 = tasks/训练量填写表.md，总量不再设 drill 级护栏。
# D15 阶梯放宽（上界 = 档数）同批被取代：阶梯每档即一个位置，一律 15 颗。

VALID_DOSE_MODES = {"sequence", "repetition"}
# repetition 型每轮球数形状约束带（§5.6.2，v34 R13）：每位置 8–15 颗，默认 15。
REPETITION_BAND = (8, 15)


def load_drill_contents(paths: Paths | None = None) -> dict[str, dict]:
    """{drillId: drill JSON}（不含 index.json）。"""
    paths = paths or DEFAULT_PATHS
    result: dict[str, dict] = {}
    if not paths.drills.is_dir():
        return result
    for path in sorted(paths.drills.rglob("*.json")):
        if path.name == "index.json":
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue  # I10 负责报语法错误，这里不重复
        if isinstance(data, dict):
            result[data.get("id") or path.stem] = data
    return result


def measured_shots(path: Path) -> int:
    """序列实测杆数 = `steps` 长度（口径同 §1.2 红线 3：走脚本取值，不看文案）。"""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return -1
    steps = data.get("steps")
    return len(steps) if isinstance(steps, list) else -1


def per_formation(drill: dict) -> list[dict]:
    sets = drill.get("sets")
    if not isinstance(sets, dict):
        return []
    items = sets.get("perFormation")
    return [item for item in items if isinstance(item, dict)] if isinstance(items, list) else []


def check_dose_tokens(sequences: dict[str, list[dict]], drills: dict[str, dict],
                      exempt: dict[str, list[str]]) -> dict:
    """I6a：有序列 drill 的 `perFormation` token 集合 == 序列 token 集合。"""
    ok, fail, exempted, warn = 0, [], [], []
    for drill_id, drill in sorted(drills.items()):
        seq_items = sequences.get(drill_id) or []
        per = per_formation(drill)

        if not seq_items:
            # 结构性豁免：无序列 drill 人工定量（§5.6.4）。写了 perFormation 反而是错的。
            if per:
                fail.append((drill_id, "无序列却写了 perFormation",
                             "无序列 drill 只写两个汇总值（§5.6.4）"))
            continue

        seq_tokens = {item["token"] for item in seq_items}
        dose_tokens = {str(item.get("token")) for item in per}
        if dose_tokens == seq_tokens:
            if drill_id in exempt:
                warn.append((drill_id, "豁免已可解除（token 已与序列一致）",
                             "请从 i6a_token_mismatch_exempt 删除"))
            else:
                ok += 1
            continue
        detail = (drill_id,
                  "/".join(sorted(dose_tokens)) or "—",
                  "/".join(sorted(seq_tokens)) or "—")
        registered = set(exempt.get(drill_id) or [])
        (exempted if registered and registered == dose_tokens else fail).append(detail)
    return {"ok": ok, "fail": fail, "exempt": exempted, "warn": warn}


def check_dose_shots(sequences: dict[str, list[dict]], drills: dict[str, dict],
                     exempt: dict[str, list[str]]) -> dict:
    """I6b：`sequence` 型球形的 `ballsPerRound` == 该球形序列实测杆数。

    `repetition` 型按 §5.6.2 豁免几何锁死（计入 rule_exempt 计数），但受**阻塞级
    形状约束**（v34 R13）：`ballsPerRound ∈ [8,15]`（默认 15，非 15 须 `doseNote`）
    且 `defaultRounds == 序列实测杆数`（轮 = 位置，例外须 `doseNote`）。
    空序列（0 杆）球形人工定量，形状约束不适用（§5.6.4）。
    """
    ok, fail, exempted, warn = 0, [], [], []
    rule_exempt = 0
    for drill_id, drill in sorted(drills.items()):
        shots_by_token = {item["token"]: measured_shots(item["path"])
                          for item in (sequences.get(drill_id) or [])}
        registered = set(exempt.get(drill_id) or [])
        for item in per_formation(drill):
            token = str(item.get("token"))
            where = f"{drill_id}/{token}"
            mode = item.get("mode")
            balls = item.get("ballsPerRound")
            if mode not in VALID_DOSE_MODES:
                fail.append((where, f"非法 mode {mode!r}",
                             f"合法取值：{'/'.join(sorted(VALID_DOSE_MODES))}（§5.6.2）"))
                continue
            shots = shots_by_token.get(token)
            if mode == "repetition":
                rule_exempt += 1
                if not shots:
                    continue  # 空序列（0 杆）人工定量，形状约束不适用（§5.6.4）
                note = item.get("doseNote")
                rounds = item.get("defaultRounds")
                if not isinstance(balls, int) or not (
                        REPETITION_BAND[0] <= balls <= REPETITION_BAND[1]):
                    fail.append((where, f"repetition 型 ballsPerRound={balls} 超出形状"
                                        f"约束 {REPETITION_BAND[0]}–{REPETITION_BAND[1]}",
                                 "每位置 8–15 颗，默认 15（§5.6.2，v34 R13）"))
                    continue
                if balls != REPETITION_BAND[1] and not note:
                    fail.append((where, f"repetition 型 ballsPerRound={balls} ≠ 15 且无 doseNote",
                                 "非 15 须在该球形写 doseNote 说明理由（§5.6.2）"))
                    continue
                if rounds != shots and not note:
                    fail.append((where, f"repetition 型 defaultRounds={rounds} ≠ 实测杆数 {shots}",
                                 "轮 = 位置，位置全覆盖：defaultRounds 必须 = 序列杆数；"
                                 "例外须写 doseNote（§5.6.2）"))
                    continue
                ok += 1
                continue
            # sequence 型：锁死实测杆数。
            if shots is None:
                fail.append((where, "sequence 型但 token 无对应序列文件",
                             "改 token 或改 mode（§5.6.2）"))
                continue
            if balls == shots:
                if token in registered:
                    warn.append((where, "豁免已可解除（ballsPerRound 已等于实测杆数）",
                                 "请从 i6b_shots_exempt 删除"))
                else:
                    ok += 1
                continue
            detail = (where, f"ballsPerRound={balls}", f"实测杆数 {shots}")
            (exempted if token in registered else fail).append(detail)
    return {"ok": ok, "fail": fail, "exempt": exempted, "warn": warn,
            "rule_exempt": rule_exempt}


def _dose_errors(drill_id: str, dose: object, per_meta: dict[str, object],
                 seq_tokens: set[str]) -> list[tuple[str, str]]:
    """I11 单条目的 dose 结构与外键判定，返回 (问题, 处置) 列表。

    `per_meta` = {token: {defaultRounds, ballsPerRound, mode}}。
    v38 R7：`repetition` 不得靠降 rounds 砍位置（decay 也不行），减量写 ballsPerRound；
    `sequence` 在 decay 时才允许 rounds < defaultRounds，禁止改 ballsPerRound。
    """
    if not isinstance(dose, dict):
        return [("dose 不是对象", "计划条目必须写 dose（契约 §6.6）")]
    uniform = dose.get("roundsPerFormation")
    listed = dose.get("formations")
    if (uniform is None) == (listed is None):
        return [("roundsPerFormation / formations 未恰好二选一",
                 "两者必须且只能有一个（§6.6）")]
    errors: list[tuple[str, str]] = []
    decay = dose.get("decay")
    if decay is not None and not isinstance(decay, bool):
        errors.append((f"decay={decay!r} 非法", "必须是 bool（契约 §6.6 复习减量）"))
    review_from = dose.get("reviewFrom")
    if review_from is not None and not isinstance(review_from, str):
        errors.append((f"reviewFrom={review_from!r} 非法", "必须是计划 id 字符串"))
    allow_decay = decay is True
    if uniform is not None:
        if not isinstance(uniform, int) or isinstance(uniform, bool) or uniform < 1:
            errors.append((f"roundsPerFormation={uniform!r} 非法", "必须是 ≥1 的整数（倍数语义，§6.6）"))
        return errors
    if not isinstance(listed, list) or not listed:
        return [("formations 为空或非数组", "至少列 1 个球形，或改用 roundsPerFormation")]
    for entry in listed:
        if not isinstance(entry, dict):
            errors.append((f"formations 元素 {entry!r} 非对象", "需 {token, rounds}"))
            continue
        token, rounds = entry.get("token"), entry.get("rounds")
        plan_bpr = entry.get("ballsPerRound")
        if not isinstance(rounds, int) or isinstance(rounds, bool) or rounds < 1:
            errors.append((f"token `{token}` 的 rounds={rounds!r} 非法", "必须是 ≥1 的整数"))
        if plan_bpr is not None and (
            not isinstance(plan_bpr, int) or isinstance(plan_bpr, bool) or plan_bpr < 1
        ):
            errors.append((f"token `{token}` 的 ballsPerRound={plan_bpr!r} 非法",
                           "必须是 ≥1 的整数（v38 R7 计划侧重复维）"))
        if token not in per_meta:
            errors.append((f"token `{token}` 不在该 drill 的 perFormation "
                           f"{sorted(per_meta)} 中",
                           "token 是计划外键（§6 规则 2）：先改计划再改内容"))
            continue
        if token not in seq_tokens:
            errors.append((f"token `{token}` 不在该 drill 的序列 token "
                           f"{sorted(seq_tokens)} 中", "序列是球形真源（§1.1）"))
        meta = per_meta[token]
        floor = meta.get("defaultRounds")
        content_bpr = meta.get("ballsPerRound")
        mode = meta.get("mode")
        if (isinstance(rounds, int) and not isinstance(rounds, bool)
                and isinstance(floor, int) and not isinstance(floor, bool)
                and rounds < floor):
            if mode == "repetition":
                errors.append((
                    f"token `{token}` 的 rounds={rounds} 低于内容 defaultRounds={floor}（砍位置）",
                    "repetition 衰减不得砍杆，应保 rounds=defaultRounds、降 ballsPerRound（§6.6 / v38 R7）"
                ))
            elif not allow_decay:
                errors.append((f"token `{token}` 的 rounds={rounds} 低于内容 defaultRounds={floor}",
                               "逐球形轮数不得低于该球形 defaultRounds——位置永远全覆盖（§6.6，v34 R9）；"
                               "sequence 复习减量须标 decay: true（v37 D-v37-2=B / v38 R7）"))
        if plan_bpr is not None and isinstance(plan_bpr, int) and not isinstance(plan_bpr, bool):
            if mode == "sequence" and isinstance(content_bpr, int) and plan_bpr != content_bpr:
                errors.append((
                    f"token `{token}` 的 ballsPerRound={plan_bpr} 改了 sequence 链长（内容 {content_bpr}）",
                    "sequence 杆数锁死为内容 ballsPerRound，衰减只降 rounds（§6.6 / v38 R7）"
                ))
            if mode == "repetition" and isinstance(content_bpr, int):
                if plan_bpr > content_bpr:
                    errors.append((
                        f"token `{token}` 的 ballsPerRound={plan_bpr} 高于内容 {content_bpr}",
                        "计划侧只能降每位置颗数，不能加量（§6.6 / v38 R7）"
                    ))
                if plan_bpr < content_bpr and not allow_decay:
                    errors.append((
                        f"token `{token}` 的 ballsPerRound={plan_bpr} 低于内容 {content_bpr} 但未标 decay",
                        "降每位置颗数必须 decay: true（§6.6 / v38 R7）"
                    ))
    return errors


def check_plan_refs(sequences: dict[str, list[dict]], drills: dict[str, dict],
                    paths: Paths | None = None) -> dict:
    """I11：官方计划每条目 drillId 存在、dose 可解析、按球形引用的 token 是有效外键。"""
    paths = paths or DEFAULT_PATHS
    if not paths.plans.is_dir():
        return {"ok": 0, "fail": [], "exempt": [], "warn": [("—", "Plans 目录不存在", "—")]}
    index_path = paths.drills / "index.json"
    if not index_path.is_file():
        return {"ok": 0, "fail": [], "exempt": [],
                "warn": [("—", "index.json 不存在，无法校验 drillId", "—")]}
    index = json.loads(index_path.read_text(encoding="utf-8"))
    index_ids = {drill_id
                 for category in index.get("categories", [])
                 for drill_id in category.get("drills", [])}

    ok, fail, warn = 0, [], []
    for path in sorted(paths.plans.glob("plan_*.json")):
        plan_id = path.stem
        try:
            plan = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            fail.append((plan_id, "JSON 语法错误", str(exc)))
            continue
        for week in plan.get("weeks") or []:
            for session in week.get("sessions") or []:
                where_s = f"{plan_id} W{week.get('weekNumber')}D{session.get('dayNumber')}"
                for phase in session.get("phases") or []:
                    for ref in phase.get("drills") or []:
                        drill_id = ref.get("drillId")
                        where = f"{where_s} {phase.get('type')} {drill_id}"
                        if drill_id not in index_ids:
                            fail.append((where, f"drillId `{drill_id}` 不在 index.json",
                                         "计划引用的 drill 必须已登记"))
                            continue
                        if "sets" in ref or "ballsPerSet" in ref:
                            # v31 W5 起 `PlanDrillRef` 已无这两个字段，解码会静默忽略
                            # ⇒ 残留即「写了却不生效」的哑数据，按契约 §6.6 转阻塞。
                            fail.append((where, "仍残留旧格式 sets/ballsPerSet",
                                         "契约 §6.6：计划不得存裸球数（字段已于 W5 删除，写了也不会生效）"))
                            continue
                        drill = drills.get(drill_id) or {}
                        per_meta = {
                            str(item.get("token")): {
                                "defaultRounds": item.get("defaultRounds"),
                                "ballsPerRound": item.get("ballsPerRound"),
                                "mode": item.get("mode"),
                            }
                            for item in per_formation(drill)
                        }
                        seq_tokens = {item["token"] for item in (sequences.get(drill_id) or [])}
                        errors = _dose_errors(drill_id, ref.get("dose"), per_meta, seq_tokens)
                        if errors:
                            fail += [(where, what, how) for what, how in errors]
                        else:
                            ok += 1
    return {"ok": ok, "fail": fail, "exempt": [], "warn": warn}


LOAD_AXES_KEYS = ("aim", "cue", "spin", "position", "constraint", "speed")


def _load_axis_errors(load: object, where: str) -> list[tuple[str, str, str]]:
    """校验一个 `load` 对象：六键齐全、整数 0–4。返回 (where, what, how) 行。"""
    if not isinstance(load, dict):
        return [(where, "缺 load 或类型不是对象",
                 "契约 §5.7.4：load 为 {aim,cue,spin,position,constraint,speed} 六键对象")]
    errors: list[tuple[str, str, str]] = []
    missing = [key for key in LOAD_AXES_KEYS if key not in load]
    if missing:
        errors.append((where, f"load 缺键 {','.join(missing)}",
                       "六键 aim/cue/spin/position/constraint/speed 必须齐全"))
    for key in LOAD_AXES_KEYS:
        if key not in load:
            continue
        value = load[key]
        if not isinstance(value, int) or isinstance(value, bool) or value < 0 or value > 4:
            errors.append((where, f"load.{key}={value!r} 值域非法",
                           "必须是整数 0–4（契约 §5.7）"))
    return errors


def _loads_equal(left: dict, right: dict) -> bool:
    return all(left.get(key) == right.get(key) for key in LOAD_AXES_KEYS)


def check_load_axes(drills: dict[str, dict], paths: Paths | None = None) -> dict:
    """I12：六轴 load 齐全、值域 0–4；代表分 = 代表球形实分（契约 §5.7.5）。

    组课 max 可由被引用球形各轴独立取 max 派生——本检查只保证字段在就能算。
    计划侧包络比较见 I13。
    """
    paths = paths or DEFAULT_PATHS
    index_path = paths.drills / "index.json"
    if not index_path.is_file():
        return {"ok": 0, "fail": [], "exempt": [],
                "warn": [("—", "index.json 不存在，无法校验 load", "—")]}
    index = json.loads(index_path.read_text(encoding="utf-8"))
    index_ids = [drill_id
                 for category in index.get("categories", [])
                 for drill_id in category.get("drills", [])]

    ok, fail, warn = 0, [], []
    for drill_id in index_ids:
        drill = drills.get(drill_id) or {}
        sets = drill.get("sets") if isinstance(drill.get("sets"), dict) else {}
        formations = per_formation(drill)
        top_load = drill.get("load")

        if formations:
            token_set: set[str] = set()
            loads_by_token: dict[str, dict] = {}
            for item in formations:
                token = str(item.get("token"))
                token_set.add(token)
                where = f"{drill_id}/{token}"
                errors = _load_axis_errors(item.get("load"), where)
                if errors:
                    fail += errors
                else:
                    loads_by_token[token] = item["load"]
                    ok += 1

            rep = sets.get("representativeToken")
            if rep is not None and rep != "":
                if rep not in token_set:
                    fail.append((drill_id,
                                 f"representativeToken `{rep}` 不在 perFormation {sorted(token_set)}",
                                 "契约 §5.7.5：representativeToken 若出现必须 ∈ perFormation"))
                    continue
                rep_token = rep
            else:
                first_token = formations[0].get("token")
                rep_token = str(first_token) if first_token is not None else None

            top_errors = _load_axis_errors(top_load, f"{drill_id} 顶层")
            if top_errors:
                fail += top_errors
                continue
            rep_load = loads_by_token.get(rep_token) if rep_token else None
            if rep_load is None:
                fail.append((drill_id, "代表球形 load 缺失，无法核顶层派生",
                             "先补齐 perFormation[].load"))
            elif not _loads_equal(top_load, rep_load):
                fail.append((drill_id, "drill 级 load ≠ 代表球形 load",
                             "契约 §5.7.5：顶层 load 必须原样拷贝代表球形实分"))
            else:
                ok += 1
        else:
            if "load" in sets:
                fail.append((drill_id, "无 perFormation 却在 sets 下出现 load",
                             "契约 §5.7.4：无序列只允许 drill 级 load，不另建平行数组"))
                continue
            if sets.get("representativeToken"):
                fail.append((drill_id, "无 perFormation 却写了 representativeToken",
                             "契约 §5.7.4：无序列不写 representativeToken"))
                continue
            errors = _load_axis_errors(top_load, drill_id)
            if errors:
                fail += errors
            else:
                ok += 1
    return {"ok": ok, "fail": fail, "exempt": [], "warn": warn}


# ── I13：排课规则（v37 W5，契约 §7 / R4–R6）────────────────────────────────
#
# 操作定义（对照现网计划实测后钉死，写入契约 2.9 / 2.11 / 2.12）：
# 1. 建议周下界（v39 W2）：每份计划内 focused 首次引入的短 id，其首次周不得
#    早于 `docs/research/20260818-v39-语义课表.md` §5 该 (plan, id) 的建议周。
#    六轴 scalar 不再卡周（只给 ② 热身≤主课用）。warmup / reviewFrom 咬合
#    不计入「首次引入」。缺表或不足 83 条 ⇒ FAIL。
# 2. 热身≤主课：同 session 非咬合热身的 scalar max ≤ focused scalar max。
#    带 reviewFrom 的热身豁免（R6 上一档末段 → 下一档热身，允许高于开档主课）。
#    逐轴比较会在现网打出 61 课假红，不用。
# 3. 衰减：同 drill 按课次顺序剂量（展开球数）单调不增；低于完整剂量必须 decay。
# 4. reviewFrom 必须是货架计划 id，且来源计划实际包含该 drill。
# 5. 引入序（v38 W7）：每份计划 focused 首次引入的短 id 序 = W0 §3 该计划主课表序。
#    只比序，不比「建议周」。

_PHASE_ORDER = {"warmup": 0, "focused": 1, "review": 2}
_W0_ROSTER_REL = Path("docs") / "research" / "20260814-v38-先决与主课名单.md"
_V39_CURRICULUM_REL = Path("docs") / "research" / "20260818-v39-语义课表.md"


def _short_drill_id(drill_id: object) -> str:
    text = str(drill_id or "")
    return text.removeprefix("drill_") if text.startswith("drill_") else text


def _load_w0_main_order(paths: Paths) -> tuple[dict[str, list[str]], list[tuple[str, str, str]]]:
    """W0 §3 去向表：{plan_id: [c011, ...]} 按表序。找不到表或解析不足 83 条则失败。"""
    errors: list[tuple[str, str, str]] = []
    roster_path = None
    for candidate in (paths.root / _W0_ROSTER_REL, REPO_ROOT / _W0_ROSTER_REL):
        if candidate.is_file():
            roster_path = candidate
            break
    if roster_path is None:
        return {}, [("W0表", "找不到先决与主课名单", str(_W0_ROSTER_REL))]

    orders: dict[str, list[str]] = {}
    in_section = False
    for line in roster_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## 3."):
            in_section = True
            continue
        if in_section and line.startswith("## ") and not line.startswith("## 3."):
            break
        if not in_section or not line.startswith("|"):
            continue
        parts = [part.strip() for part in line.strip().strip("|").split("|")]
        if len(parts) < 4:
            continue
        drill_id, dest, plan_id = parts[0], parts[2], parts[3]
        if dest != "主课" or not drill_id.startswith("c") or not plan_id.startswith("plan_"):
            continue
        orders.setdefault(plan_id, []).append(drill_id)

    total = sum(len(ids) for ids in orders.values())
    if total != 83:
        errors.append((
            "W0表",
            f"解析到 {total} 条主课，期望 83",
            f"{roster_path} §3 去向表",
        ))
    return orders, errors


def _load_v39_suggested_weeks(
    paths: Paths,
) -> tuple[dict[tuple[str, str], int], list[tuple[str, str, str]]]:
    """语义课表 §5：{(plan_id, short_id): 建议周}。缺表或不足 83 条则失败。"""
    errors: list[tuple[str, str, str]] = []
    curriculum_path = None
    for candidate in (paths.root / _V39_CURRICULUM_REL, REPO_ROOT / _V39_CURRICULUM_REL):
        if candidate.is_file():
            curriculum_path = candidate
            break
    if curriculum_path is None:
        return {}, [("语义课表", "找不到 v39 语义课表", str(_V39_CURRICULUM_REL))]

    weeks: dict[tuple[str, str], int] = {}
    in_section = False
    for line in curriculum_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## 5."):
            in_section = True
            continue
        if in_section and line.startswith("## ") and not line.startswith("## 5."):
            break
        if not in_section or not line.startswith("|"):
            continue
        parts = [part.strip() for part in line.strip().strip("|").split("|")]
        if len(parts) < 3:
            continue
        drill_id, plan_id, week_text = parts[0], parts[1], parts[2]
        if not drill_id.startswith("c") or not plan_id.startswith("plan_"):
            continue
        try:
            week = int(week_text)
        except ValueError:
            errors.append((
                "语义课表",
                f"{drill_id} 建议周无法解析为整数：{week_text!r}",
                f"{curriculum_path} §5",
            ))
            continue
        key = (plan_id, drill_id)
        if key in weeks:
            errors.append((
                "语义课表",
                f"重复行 {plan_id}/{drill_id}",
                f"{curriculum_path} §5",
            ))
            continue
        weeks[key] = week

    if len(weeks) != 83:
        errors.append((
            "语义课表",
            f"解析到 {len(weeks)} 条建议周，期望 83",
            f"{curriculum_path} §5 建议周总表",
        ))
    return weeks, errors


def _scalar_max(drill: dict) -> int:
    raw = drill.get("load") if isinstance(drill.get("load"), dict) else {}
    values = []
    for key in LOAD_AXES_KEYS:
        value = raw.get(key)
        if isinstance(value, int) and not isinstance(value, bool):
            values.append(value)
    return max(values) if values else 0


def _dose_balls(drill: dict, dose: object) -> int | None:
    """一条计划引用展开后的总球数。结构坏时返回 None（交给 I11）。"""
    if not isinstance(dose, dict):
        return None
    listed = dose.get("formations")
    if listed is not None:
        if not isinstance(listed, list):
            return None
        per = {str(item.get("token")): item for item in per_formation(drill)}
        total = 0
        for entry in listed:
            if not isinstance(entry, dict):
                return None
            token, rounds = entry.get("token"), entry.get("rounds")
            if not isinstance(rounds, int) or isinstance(rounds, bool) or rounds < 1:
                return None
            item = per.get(str(token)) or {}
            content_balls = item.get("ballsPerRound")
            plan_balls = entry.get("ballsPerRound")
            if isinstance(plan_balls, int) and not isinstance(plan_balls, bool) and plan_balls >= 1:
                balls = plan_balls
            else:
                balls = content_balls
            if not isinstance(balls, int) or isinstance(balls, bool):
                return None
            total += rounds * balls
        return total
    uniform = dose.get("roundsPerFormation")
    if not isinstance(uniform, int) or isinstance(uniform, bool) or uniform < 1:
        return None
    sets = drill.get("sets") if isinstance(drill.get("sets"), dict) else {}
    default_sets = sets.get("defaultSets")
    default_balls = sets.get("defaultBallsPerSet")
    if (isinstance(default_sets, int) and not isinstance(default_sets, bool)
            and isinstance(default_balls, int) and not isinstance(default_balls, bool)):
        return uniform * default_sets * default_balls
    return None


def _full_balls(drill: dict) -> int:
    formations = per_formation(drill)
    if formations:
        total = 0
        for item in formations:
            rounds, balls = item.get("defaultRounds"), item.get("ballsPerRound")
            if (isinstance(rounds, int) and not isinstance(rounds, bool)
                    and isinstance(balls, int) and not isinstance(balls, bool)):
                total += rounds * balls
        return total
    sets = drill.get("sets") if isinstance(drill.get("sets"), dict) else {}
    default_sets = sets.get("defaultSets")
    default_balls = sets.get("defaultBallsPerSet")
    if (isinstance(default_sets, int) and not isinstance(default_sets, bool)
            and isinstance(default_balls, int) and not isinstance(default_balls, bool)):
        return default_sets * default_balls
    return 0


def _iter_plan_refs(plan: dict):
    """按周序 / 日序 / 相位序产出 (week, day, phase_type, ref, where)。"""
    plan_id = plan.get("id") or "?"
    weeks = sorted(plan.get("weeks") or [],
                   key=lambda week: week.get("weekNumber") or 0)
    for week in weeks:
        week_number = week.get("weekNumber")
        sessions = sorted(week.get("sessions") or [],
                          key=lambda session: session.get("dayNumber") or 0)
        for session in sessions:
            day_number = session.get("dayNumber")
            phases = sorted(session.get("phases") or [],
                            key=lambda phase: _PHASE_ORDER.get(phase.get("type"), 99))
            for phase in phases:
                phase_type = phase.get("type")
                for ref in phase.get("drills") or []:
                    if not isinstance(ref, dict):
                        continue
                    drill_id = ref.get("drillId")
                    where = f"{plan_id} W{week_number}D{day_number} {phase_type} {drill_id}"
                    yield week_number, day_number, phase_type, ref, where


def check_plan_curriculum(drills: dict[str, dict], paths: Paths | None = None) -> dict:
    """I13：官方计划排课规则（建议周下界 / 热身 / 衰减 / 咬合外键 / 引入序）。"""
    paths = paths or DEFAULT_PATHS
    if not paths.plans.is_dir():
        return {"ok": 0, "fail": [], "exempt": [], "warn": [("—", "Plans 目录不存在", "—")]}
    index_path = paths.plans / "index.json"
    if not index_path.is_file():
        return {"ok": 0, "fail": [], "exempt": [],
                "warn": [("—", "Plans/index.json 不存在", "—")]}
    try:
        index = json.loads(index_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {"ok": 0, "fail": [("Plans/index.json", "JSON 语法错误", str(exc))],
                "exempt": [], "warn": []}
    index_ids = {item.get("id") for item in (index.get("plans") or []) if item.get("id")}
    roster, roster_errors = _load_w0_main_order(paths)
    suggested, suggested_errors = _load_v39_suggested_weeks(paths)

    plans: list[dict] = []
    membership: dict[str, set[str]] = {}
    ok, fail, warn = 0, [], []
    fail.extend(roster_errors)
    fail.extend(suggested_errors)
    for path in sorted(paths.plans.glob("plan_*.json")):
        try:
            plan = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            fail.append((path.stem, "JSON 语法错误", str(exc)))
            continue
        if not isinstance(plan, dict):
            fail.append((path.stem, "计划根不是对象", "OfficialPlan 必须是对象"))
            continue
        plan_id = plan.get("id") or path.stem
        plans.append(plan)
        membership[plan_id] = {
            ref.get("drillId")
            for *_, ref, __ in _iter_plan_refs(plan)
            if ref.get("drillId")
        }

    for plan in plans:
        plan_id = plan.get("id") or "?"
        first_focused_week: dict[str, object] = {}
        session_refs: dict[tuple, dict[str, list]] = defaultdict(
            lambda: {"warmup": [], "focused": []})
        by_drill: dict[str, list] = defaultdict(list)

        for week_number, day_number, phase_type, ref, where in _iter_plan_refs(plan):
            drill_id = ref.get("drillId")
            if not drill_id:
                continue
            by_drill[drill_id].append((where, ref))
            if phase_type in ("warmup", "focused"):
                session_refs[(week_number, day_number)][phase_type].append(ref)
            if phase_type == "focused" and drill_id not in first_focused_week:
                first_focused_week[drill_id] = week_number

        for drill_id, week_number in first_focused_week.items():
            short = _short_drill_id(drill_id)
            key = (plan_id, short)
            if key not in suggested:
                fail.append((
                    f"{plan_id} {drill_id}",
                    f"语义课表 §5 没有 {plan_id}/{short} 的建议周",
                    "I13 ①：focused 首次引入必须能对照建议周总表",
                ))
                continue
            suggested_week = suggested[key]
            try:
                actual_week = int(week_number)
            except (TypeError, ValueError):
                fail.append((
                    f"{plan_id} {drill_id}",
                    f"首次引入周无法解析：{week_number!r}",
                    "I13 ①：weekNumber 必须是整数",
                ))
                continue
            if actual_week < suggested_week:
                fail.append((
                    f"{plan_id} W{actual_week} {drill_id}",
                    f"首次引入第 {actual_week} 周早于建议周 {suggested_week}",
                    f"I13 ①：focused 首次引入不得早于语义课表建议周（{short}）",
                ))
            else:
                ok += 1

        for (week_number, day_number), phases in session_refs.items():
            where = f"{plan_id} W{week_number}D{day_number}"
            warmup_refs = [
                ref for ref in phases["warmup"]
                if not (isinstance(ref.get("dose"), dict) and ref["dose"].get("reviewFrom"))
            ]
            focused_refs = phases["focused"]
            if not warmup_refs:
                continue
            if not focused_refs:
                fail.append((where, "有非咬合热身但无主课",
                             "热身≤主课需要 focused 包络"))
                continue
            warmup_scalar = max(_scalar_max(drills.get(ref.get("drillId")) or {})
                                for ref in warmup_refs)
            focused_scalar = max(_scalar_max(drills.get(ref.get("drillId")) or {})
                                 for ref in focused_refs)
            if warmup_scalar > focused_scalar:
                fail.append((where, f"热身 scalar {warmup_scalar} > 主课 {focused_scalar}",
                             "同课热身六轴 max 不得高于 focused（咬合 reviewFrom 热身豁免）"))
            else:
                ok += 1

        for drill_id, rows in by_drill.items():
            drill = drills.get(drill_id) or {}
            full = _full_balls(drill)
            previous = None
            for nth, (where, ref) in enumerate(rows):
                dose = ref.get("dose") if isinstance(ref.get("dose"), dict) else {}
                balls = _dose_balls(drill, dose)
                decay = dose.get("decay") is True
                if balls is None:
                    continue
                if nth == 0 and decay:
                    fail.append((where, "计划内首次出现标了 decay",
                                 "§6.6：首次引入不得 decay，须完整剂量"))
                elif previous is not None and balls > previous:
                    fail.append((where, f"复现剂量 {balls} > 上次 {previous}",
                                 "同 drill 复现课次剂量单调不增"))
                elif full and balls < full and not decay:
                    fail.append((where, f"剂量 {balls} < 完整 {full} 但未标 decay",
                                 "减量条目必须带 decay: true"))
                else:
                    ok += 1
                previous = balls

            for where, ref in rows:
                dose = ref.get("dose") if isinstance(ref.get("dose"), dict) else {}
                review_from = dose.get("reviewFrom")
                if not review_from:
                    continue
                if review_from not in index_ids:
                    fail.append((where, f"reviewFrom `{review_from}` 不是货架计划 id",
                                 "跨计划咬合外键必须 ∈ Plans/index.json"))
                elif drill_id not in membership.get(review_from, set()):
                    fail.append((where, f"reviewFrom `{review_from}` 中没有 {drill_id}",
                                 "来源计划必须实际包含该 drill"))
                else:
                    ok += 1

        first_focused_ids = [_short_drill_id(drill_id) for drill_id in first_focused_week]
        expected = roster.get(plan_id)
        if expected is None:
            fail.append((plan_id, "W0 §3 没有该计划的主课名单",
                         "引入序对照 W0 表：货架计划必须出现在去向表"))
        elif first_focused_ids != expected:
            fail.append((
                plan_id,
                f"引入序 {first_focused_ids} ≠ W0 表 {expected}",
                "I13 内容层：focused 首次引入序对照 W0 §3（只比序，不比建议周）",
            ))
        else:
            ok += 1

    return {"ok": ok, "fail": fail, "exempt": [], "warn": warn}


# ── I10：App 模型可解码性 ────────────────────────────────────────────────
#
# 契约 §7 I10。这份 schema 是 `QiuJi/Data/Services/DrillContentService.swift` 的
# `Codable` 结构（+ `Core/Physics/ShotIntent.swift`）的 Python 镜像：`True` = 非可选
# （Swift 里 `let x: T`），`False` = 可选（`let x: T?`）。改 Swift 模型必须同步改这里，
# 否则本检查会立刻在全库 77 条 drill 上暴露差异。
#
# 存在理由（FL-029）：`loadDrillFromBundle` 的 `try?` 曾吞掉 `DecodingError`，
# 34/77 条 drill 因缺 `TutorialSection.content` / `TutorialFormation.id` 而
# 静默不进 App，测试红了很久也没人能从「返回 nil」里看出是哪个字段。

STR, INT, DBL, BOOL = "string", "int", "double", "bool"

MODEL_SPEC: dict[str, dict[str, tuple[bool, object]]] = {
    "DrillContent": {
        "id": (True, STR), "nameZh": (True, STR), "nameEn": (True, STR),
        "category": (True, STR),
        # v31 W0：副分类标签，可选数组（每条 ≤1 个，内容侧约束见契约 §3.3）。
        "secondaryCategories": (False, ["string"]),
        "subcategory": (True, STR),
        "ballType": (True, ["string"]), "level": (True, STR),
        "difficulty": (True, INT), "isPremium": (True, BOOL),
        "description": (True, STR), "coachingPoints": (True, ["string"]),
        "standardCriteria": (True, STR),
        "sets": (True, "DrillSetsConfig"), "animation": (True, "DrillAnimation"),
        "tutorial": (False, "DrillTutorial"), "videos": (False, ["DrillVideo"]),
        "shotIntent": (False, "ShotIntent"),
        # v37 W1：六轴代表分（契约 §5.7）。可选——齐全性由 I12 阻塞，I10 不因缺 load 失败。
        "load": (False, "LoadAxes"),
    },
    # v37 W1：六轴执行负荷（契约 §5.7）。六键均必填 Int；对象本身在宿主上可选。
    "LoadAxes": {
        "aim": (True, INT), "cue": (True, INT), "spin": (True, INT),
        "position": (True, INT), "constraint": (True, INT), "speed": (True, INT),
    },
    # v31 W0：`perFormation` 逐球形剂量，可选（无序列 drill 省略，契约 §5.6.4）。
    # v37 W1：`representativeToken` 可选；缺省 = perFormation[0]（契约 §5.7.5）。
    "DrillSetsConfig": {"defaultSets": (True, INT), "defaultBallsPerSet": (True, INT),
                        "perFormation": (False, ["FormationDose"]),
                        "representativeToken": (False, STR)},
    # v34 W0：`doseNote` 可选——有意例外剂量的说明（R3；门禁 I6b 凭 note 豁免形状约束）。
    # v37 W1：`load` 可选（与 Swift 镜像）；齐全性由 I12 阻塞。
    "FormationDose": {"token": (True, STR), "mode": (True, ["sequence", "repetition"]),
                      "ballsPerRound": (True, INT), "defaultRounds": (True, INT),
                      "doseNote": (False, STR),
                      "load": (False, "LoadAxes")},
    "DrillVideo": {"id": (True, STR), "file": (True, STR)},
    "DrillAnimation": {
        "cueBall": (True, "BallAnimation"), "targetBall": (True, "BallAnimation"),
        "pocket": (True, STR), "cueDirection": (True, "CanvasPoint"),
        "source": (False, STR), "generator": (False, STR),
    },
    "BallAnimation": {"start": (True, "CanvasPoint"), "path": (True, ["PathPoint"])},
    "CanvasPoint": {"x": (True, DBL), "y": (True, DBL)},
    "PathPoint": {"x": (True, DBL), "y": (True, DBL),
                  "cp1": (False, "CanvasPoint"), "cp2": (False, "CanvasPoint")},
    "DrillTutorial": {
        "tutorialKind": (False, ["singleShot", "multiShot", "ruleset"]),
        "sections": (False, ["TutorialSection"]),
        "formations": (False, ["TutorialFormation"]),
    },
    "TutorialFormation": {"id": (True, STR), "title": (True, STR),
                          "sections": (True, ["TutorialSection"])},
    "TutorialSection": {
        "title": (True, STR),
        # v30 X-1：放宽为可选——「常见错误与纠正」这类纯 items 节本就无正文。
        "content": (False, STR),
        "image": (False, STR), "clip": (False, STR), "caption": (False, STR),
        "items": (False, ["TutorialItem"]), "params": (False, "TutorialShotParams"),
    },
    "TutorialItem": {"label": (True, STR), "text": (True, STR)},
    "TutorialShotParams": {"spinX": (True, DBL), "spinY": (True, DBL),
                           "velocity": (True, DBL)},
    "ShotIntent": {"version": (True, INT), "shots": (True, ["ShotIntentShot"])},
    "ShotIntentShot": {
        "cue": (True, "CanvasPoint"), "target": (True, "CanvasPoint"),
        "pocket": (True, STR), "velocity": (True, DBL),
        "spin": (False, "ShotIntentSpin"), "elevation": (False, DBL),
        "obstacles": (False, ["CanvasPoint"]),
    },
    "ShotIntentSpin": {"x": (True, DBL), "y": (True, DBL)},
    "DrillIndex": {"version": (True, INT), "categories": (True, ["DrillIndexCategory"])},
    "DrillIndexCategory": {"category": (True, STR), "drills": (True, ["string"])},
    # 计划侧模型（`PlanContentService.swift`）。解码失败时 `loadAllPlans` 的 compactMap
    # 会让整份计划从列表里消失，与 FL-029 的「静默不进 App」同一形态，故一并镜像。
    "OfficialPlan": {
        "id": (True, STR), "nameZh": (True, STR), "nameEn": (True, STR),
        "targetLevel": (True, STR), "durationWeeks": (True, INT),
        "sessionsPerWeek": (True, INT), "minutesPerSession": (True, INT),
        "isPremium": (True, BOOL), "description": (True, STR),
        "weeks": (True, ["PlanWeek"]),
    },
    "PlanWeek": {"weekNumber": (True, INT), "theme": (True, STR),
                 "sessions": (True, ["PlanSession"])},
    "PlanSession": {"dayNumber": (True, INT), "phases": (True, ["SessionPhase"])},
    "SessionPhase": {"type": (True, STR), "durationMinutes": (True, INT),
                     "drills": (True, ["PlanDrillRef"])},
    # v31 W5 已删旧格式 `sets`/`ballsPerSet`，故 spec 里也不再有（与 Swift 结构一一对应）。
    # `dose` 在 Swift 侧仍是可选，语义上的「必须有 dose」由 I11 阻塞，不在这里判。
    "PlanDrillRef": {"drillId": (True, STR), "dose": (False, "PlanDrillDose")},
    "PlanDrillDose": {"roundsPerFormation": (False, INT),
                      "formations": (False, ["PlanFormationRounds"]),
                      "decay": (False, BOOL),
                      "reviewFrom": (False, STR)},
    "PlanFormationRounds": {"token": (True, STR), "rounds": (True, INT),
                            "ballsPerRound": (False, INT)},
    "PlanIndex": {"version": (True, INT), "plans": (True, ["PlanIndexEntry"])},
    "PlanIndexEntry": {"id": (True, STR), "nameZh": (True, STR),
                       "targetLevel": (True, STR), "isPremium": (True, BOOL)},
}


def type_ok(value: object, spec: object) -> bool:
    """Codable 的类型约束（JSON 侧）：bool 不算 int/double，int 可喂 Double。"""
    if spec == STR:
        return isinstance(value, str)
    if spec == BOOL:
        return isinstance(value, bool)
    if spec == INT:
        return isinstance(value, int) and not isinstance(value, bool)
    if spec == DBL:
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    return True


def decode_errors(value: object, spec: object, path: str) -> list[str]:
    """按 MODEL_SPEC 递归模拟 `JSONDecoder`，返回 Swift 侧会抛的错误描述列表。"""
    if isinstance(spec, list):
        if len(spec) == 1 and (spec[0] in MODEL_SPEC or spec[0] == "string"):
            if not isinstance(value, list):
                return [f"typeMismatch 期望数组 @ {path}"]
            errors: list[str] = []
            for i, item in enumerate(value):
                errors += decode_errors(item, spec[0], f"{path}[{i}]")
            return errors
        # 字面量集合 = Swift enum 的 rawValue 域。
        return ([] if value in spec
                else [f"dataCorrupted 非法枚举值 {value!r}（合法：{'/'.join(spec)}） @ {path}"])
    if spec == "string":
        return [] if isinstance(value, str) else [f"typeMismatch 期望 String @ {path}"]
    if spec in MODEL_SPEC:
        if not isinstance(value, dict):
            return [f"typeMismatch 期望对象（{spec}） @ {path}"]
        errors = []
        for field, (required, field_spec) in MODEL_SPEC[spec].items():
            if field not in value or value[field] is None:
                if required:
                    errors.append(f"keyNotFound '{field}'（{spec} 必填） @ {path}")
                continue
            errors += decode_errors(value[field], field_spec, f"{path}.{field}")
        return errors
    return [] if type_ok(value, spec) else [f"typeMismatch 期望 {spec} @ {path}"]


def check_model_decodable(paths: Paths | None = None) -> dict:
    """I10：全部 bundled drill / plan（含各自 index.json）能被 App 的 Codable 模型解码。

    等价于「必填字段齐全且类型正确」。`DrillContentService` 曾用 `try?` 吞掉
    `DecodingError`，使这类内容缺陷表现为「drill 凭空消失」而非报错；
    计划侧同形态（`loadAllPlans` 的 compactMap 会让解码失败的计划整份消失）。
    """
    paths = paths or DEFAULT_PATHS
    ok, fail = 0, []
    if not paths.drills.is_dir():
        return {"ok": 0, "fail": [], "warn": [("—", "Drills 目录不存在", "—")]}
    targets = [(path, paths.drills, "DrillIndex", "DrillContent")
               for path in sorted(paths.drills.rglob("*.json"))]
    if paths.plans.is_dir():
        targets += [(path, paths.plans.parent, "PlanIndex", "OfficialPlan")
                    for path in sorted(paths.plans.glob("*.json"))]
    for path, base, index_model, item_model in targets:
        rel = path.relative_to(base).as_posix()
        model = index_model if path.name == "index.json" else item_model
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            fail.append((rel, "JSON 语法错误", str(exc)))
            continue
        errors = decode_errors(data, model, model)
        if errors:
            fail.append((rel, f"{len(errors)} 处解码错误", "；".join(errors[:3])))
        else:
            ok += 1
    return {"ok": ok, "fail": fail, "warn": []}


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
        ("I6a", "剂量 perFormation token == 序列 token", ("perFormation", "序列实际")),
        ("I6b", "sequence 型每轮球数 == 实测杆数；repetition 型形状约束", None),
        ("I7", "profile vs 序列 token", ("profile", "序列实际")),
        ("I8", "Bundle DrillBoards ⊆ 上游序列", None),
        ("I9", "登记 drill 至少 1 条序列", None),
        ("I10", "Bundle drill / plan 可被 App 模型解码", None),
        ("I11", "官方计划 drillId / dose / token 可解析", None),
        ("I12", "六轴 load 齐全 / 值域 0–4 / 代表分 = 球形实分", None),
        ("I13", "排课：建议周下界 / 热身≤主课 / 衰减单调 / 咬合外键 / 引入序", None),
    ):
        if check_id not in results:
            continue
        r = results[check_id]
        exempt = r.get("exempt", [])
        rule_exempt = r.get("rule_exempt")
        tail = f"  规则豁免 {rule_exempt}（repetition 型，§5.6.2）" if rule_exempt else ""
        print(f"\n[{check_id}] {title}  通过 {r['ok']}  违规 {len(r['fail'])}  "
              f"已知豁免 {len(exempt)}  提示 {len(r['warn'])}{tail}")

        def line(mark: str, row: tuple[str, str, str], tail: str = "",
                 paired: bool = True) -> None:
            left, mid, right = row
            body = (f"{columns[0]} {mid} vs {columns[1]} {right}" if columns and paired
                    else f"{mid} —— {right}")
            print(f"  {mark} {left}  {body}{tail}")

        for row in r["fail"]:
            line("✗", row)
        for row in exempt:
            line("⊘", row, "（已知豁免）")
        for row in r["warn"]:
            # WARN 行的第 2/3 列是「现象 —— 处置」，不是可对照的两侧取值。
            line("·", row, paired=False)


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
    if "I10" in selected:
        results["I10"] = check_model_decodable(paths)
    if {"I6a", "I6b", "I11", "I12", "I13"} & selected:
        drills = load_drill_contents(paths)
        if "I6a" in selected:
            results["I6a"] = check_dose_tokens(
                sequences, drills, baselines.get("i6a_token_mismatch_exempt", {}))
        if "I6b" in selected:
            results["I6b"] = check_dose_shots(
                sequences, drills, baselines.get("i6b_shots_exempt", {}))
        if "I11" in selected:
            results["I11"] = check_plan_refs(sequences, drills, paths)
        if "I12" in selected:
            results["I12"] = check_load_axes(drills, paths)
        if "I13" in selected:
            results["I13"] = check_plan_curriculum(drills, paths)

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

#!/usr/bin/env python3
"""Read-only inventory and quality audit for v49 learner-facing copy.

The script reads Drill JSON, the intent table, tutorial evidence, sequence files,
and the production Practice cards declared in Swift. It never writes files and
never generates learner-facing prose. Markdown output is intended to seed the
v49 audit ledger; JSON output is intended for deterministic checks.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable, Iterator


REPO = Path(__file__).resolve().parents[1]
DRILL_ROOT = REPO / "QiuJi" / "Resources" / "Drills"
INDEX_PATH = DRILL_ROOT / "index.json"
INTENT_PATH = REPO / "docs" / "research" / "20260819-动作库球形训练意图.md"
SEQUENCE_ROOT = REPO / "content" / "position_play" / "sequences"
MASTER_ROOT = REPO / "QiuJi" / "Resources" / "DrillTutorials"
PUBLISHED_ROOT = REPO / "QiuJi" / "Resources" / "TutorialFigures"
ANGLE_HOME_PATH = REPO / "QiuJi" / "Features" / "AngleTraining" / "Views" / "AngleHomeView.swift"
THEORY_CATALOG_PATH = REPO / "QiuJi" / "Features" / "AngleTraining" / "Theory" / "TheoryCatalog.swift"
ATMOSPHERE_PATH = REPO / "QiuJi" / "Core" / "DesignSystem" / "AtmosphereCatalog.swift"

EXPECTED_DRILLS = 74
EXPECTED_CARDS = 36
RULESET_IDS = {"c065", "c068", "c070"}
PILOT_PROPOSITIONS = {
    "c001": "换方向后仍保持直线出杆",
    "c011": "小角度变化后重新找到瞄准点",
    "c012": "排除目标球碰撞后，单独检验站位、瞄准与出杆",
}

BATCH_BY_ID = {
    "c001": "W1", "c011": "W1", "c012": "W1",
    "c009": "W2", "c010": "W2", "c022": "W2", "c023": "W2",
    "c013": "W3", "c032": "W3", "c033": "W3", "c063": "W3", "c072": "W3",
    "c052": "W4", "c053": "W4",
    "c076": "W5", "c077": "W5", "c078": "W5",
    "c073": "W6", "c074": "W6", "c075": "W6",
    "c003": "W7", "c004": "W7", "c014": "W7", "c015": "W7", "c016": "W7", "c017": "W7",
    "c018": "W8", "c020": "W8", "c021": "W8",
    "c024": "W9", "c025": "W9", "c026": "W9", "c027": "W9", "c028": "W9",
    "c029": "W10", "c030": "W10", "c031": "W10", "c083": "W10", "c084": "W10",
    "c005": "W11", "c034": "W11", "c035": "W11", "c036": "W11", "c037": "W11", "c038": "W11",
    "c039": "W12", "c040": "W12", "c041": "W12", "c042": "W12",
    "c079": "W13", "c080": "W13", "c081": "W13", "c082": "W13",
    "c044": "W14", "c045": "W14", "c046": "W14", "c047": "W14",
    "c048": "W14", "c049": "W14", "c050": "W14", "c051": "W14",
    "c054": "W15", "c055": "W15", "c056": "W15", "c057": "W15", "c058": "W15",
    "c060": "W16", "c085": "W16", "c064": "W16", "c065": "W16", "c068": "W16", "c070": "W16",
    "c069": "W17", "c071": "W17",
}

RISK_TERMS = (
    "档",
    "只换",
    "按示范",
    "锁中",
    "锁定",
    "锁死",
    "m/s",
    "本档",
    "这一档",
    "当前球形",
    "上图",
)

FIRST_COACHING_CONTEXT_TERMS = (
    "按示范",
    "锁中",
    "锁定",
    "锁死",
    "m/s",
    "本档",
    "这一档",
    "当前球形",
    "上图",
)


@dataclass(frozen=True)
class IntentRow:
    formation_index: str
    formation: str
    original: str
    refined: str


@dataclass(frozen=True)
class DrillAudit:
    short_id: str
    drill_id: str
    batch: str
    category: str
    name: str
    path: str
    intent_status: str
    intent_rows: tuple[IntentRow, ...]
    tutorial_path: str
    sequence_paths: tuple[str, ...]
    image_keys: tuple[str, ...]
    missing_master_keys: tuple[str, ...]
    missing_published_keys: tuple[str, ...]
    neighbor_id: str
    proposition: str
    core_status: str
    tutorial_status: str
    conflict: str
    first_coaching: str
    first_coaching_audit: str
    risk_terms: tuple[str, ...]
    description_length: int
    criteria_length: int


@dataclass(frozen=True)
class CardAudit:
    section: str
    batch: str
    route: str
    title: str
    subtitle: str
    cover_key: str
    source: str
    neighbor_title: str
    subtitle_length: int
    subtitle_display_width: int
    width_audit: str
    status: str


def relative(path: Path) -> str:
    return str(path.relative_to(REPO))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def load_index() -> list[tuple[str, str]]:
    payload = json.loads(read_text(INDEX_PATH))
    indexed: list[tuple[str, str]] = []
    for category in payload.get("categories", []):
        category_id = category["category"]
        for drill_id in category.get("drills", []):
            indexed.append((category_id, drill_id))
    return indexed


def parse_intent_table() -> dict[str, list[IntentRow]]:
    result: dict[str, list[IntentRow]] = defaultdict(list)
    for line in read_text(INTENT_PATH).splitlines():
        if not re.match(r"^\| c\d{3} \|", line):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 7:
            continue
        short_id, _, _, formation_index, formation, original, refined = cells[:7]
        result[short_id].append(IntentRow(formation_index, formation, original, refined))
    return result


def find_drill_path(drill_id: str) -> Path:
    matches = sorted(DRILL_ROOT.glob(f"*/{drill_id}.json"))
    if len(matches) != 1:
        found = ", ".join(relative(path) for path in matches) or "none"
        raise ValueError(f"{drill_id}: expected one JSON, found {found}")
    return matches[0]


def walk_image_keys(node: Any) -> Iterator[str]:
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "image" and isinstance(value, str):
                yield value
            else:
                yield from walk_image_keys(value)
    elif isinstance(node, list):
        for value in node:
            yield from walk_image_keys(value)


def effective_tutorial(data: dict[str, Any]) -> tuple[str, Any]:
    tutorial = data.get("tutorial") or {}
    formations = tutorial.get("formations") or []
    if formations:
        return "formations", formations
    sections = tutorial.get("sections") or []
    if tutorial.get("tutorialKind") == "ruleset":
        return "ruleset.sections", sections
    return "sections", sections


def normalize_text(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(normalize_text(item) for item in value)
    if isinstance(value, dict):
        return " ".join(normalize_text(item) for item in value.values())
    return ""


def intent_status(rows: Iterable[IntentRow]) -> str:
    rows = tuple(rows)
    if not rows:
        return "缺失：意图表无此 ID"
    if any(row.original.strip() for row in rows):
        return "用户意图已填写"
    if any("跳过" in row.refined or "待素材" in row.refined for row in rows):
        return "正文阻塞：用户意图为空"
    if any(row.refined.strip() for row in rows):
        return "仅完善列有内容"
    return "正文阻塞：意图两列均空"


def audit_first_coaching(value: str) -> str:
    reasons: list[str] = []
    length = len(value.strip())
    if not value.strip():
        reasons.append("为空")
    if length and length < 8:
        reasons.append("过短")
    if length > 48:
        reasons.append("偏长")
    context_terms = [term for term in FIRST_COACHING_CONTEXT_TERMS if term in value]
    if context_terms:
        reasons.append("依赖上下文词=" + "/".join(context_terms))
    if value.count("，") + value.count("；") >= 3:
        reasons.append("单条承载过多动作")
    return "待人工复核" if not reasons else "风险：" + "；".join(reasons)


def drill_audits() -> list[DrillAudit]:
    indexed = load_index()
    intents = parse_intent_table()
    category_ids: dict[str, list[str]] = defaultdict(list)
    for category, drill_id in indexed:
        category_ids[category].append(drill_id.removeprefix("drill_"))

    audits: list[DrillAudit] = []
    for category, drill_id in indexed:
        short_id = drill_id.removeprefix("drill_")
        path = find_drill_path(drill_id)
        data = json.loads(read_text(path))
        tutorial_path, tutorial_node = effective_tutorial(data)
        image_keys = tuple(dict.fromkeys(walk_image_keys(tutorial_node)))
        sequence_paths = tuple(
            relative(item) for item in sorted(SEQUENCE_ROOT.glob(f"{drill_id}__*.json"))
        )
        category_order = category_ids[category]
        position = category_order.index(short_id)
        neighbor = category_order[position + 1] if position + 1 < len(category_order) else category_order[position - 1]
        rows = tuple(intents.get(short_id, []))
        all_learner_text = " ".join(
            [
                normalize_text(data.get("nameZh")),
                normalize_text(data.get("description")),
                normalize_text(data.get("coachingPoints")),
                normalize_text(data.get("standardCriteria")),
                normalize_text(tutorial_node),
            ]
        )
        terms = tuple(term for term in RISK_TERMS if term in all_learner_text)
        first = ""
        coaching = data.get("coachingPoints") or []
        if isinstance(coaching, list) and coaching:
            first = str(coaching[0])
        conflict = "待逐课核对"
        if short_id == "c012":
            conflict = "已知：旧教程写“只拉距离、不换切角”，须在 W1 与意图/配图闭环"
        elif short_id == "c055":
            conflict = "用户训练意图为空；正文阻塞，AI 不自行补造"
        audits.append(
            DrillAudit(
                short_id=short_id,
                drill_id=drill_id,
                batch=BATCH_BY_ID.get(short_id, "未排批"),
                category=category,
                name=str(data.get("nameZh", "")),
                path=relative(path),
                intent_status=intent_status(rows),
                intent_rows=rows,
                tutorial_path=tutorial_path,
                sequence_paths=sequence_paths,
                image_keys=image_keys,
                missing_master_keys=tuple(key for key in image_keys if not (MASTER_ROOT / f"{key}.png").is_file()),
                missing_published_keys=tuple(key for key in image_keys if not (PUBLISHED_ROOT / f"{key}.heic").is_file()),
                neighbor_id=neighbor,
                proposition=PILOT_PROPOSITIONS.get(short_id, f"待 {BATCH_BY_ID.get(short_id, '对应批次')} 提炼"),
                core_status="候选样张，待 W1 定调" if short_id in PILOT_PROPOSITIONS else f"待 {BATCH_BY_ID.get(short_id, '对应批次')}",
                tutorial_status=f"待 {BATCH_BY_ID.get(short_id, '对应批次')}",
                conflict=conflict,
                first_coaching=first,
                first_coaching_audit=audit_first_coaching(first),
                risk_terms=terms,
                description_length=len(str(data.get("description", ""))),
                criteria_length=len(str(data.get("standardCriteria", ""))),
            )
        )
    return audits


def swift_string(value: str) -> str:
    return value.replace(r"\n", "\n").replace(r'\"', '"').replace(r"\\", "\\")


def extract_declared_array(source: str, declaration: str) -> str:
    marker = f"private let {declaration}: [AngleEntry] = ["
    start = source.find(marker)
    if start < 0:
        raise ValueError(f"missing Swift array: {declaration}")
    cursor = start + len(marker)
    depth = 1
    in_string = False
    escaped = False
    while cursor < len(source):
        char = source[cursor]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char == "[":
            depth += 1
        elif char == "]":
            depth -= 1
            if depth == 0:
                return source[start + len(marker):cursor]
        cursor += 1
    raise ValueError(f"unterminated Swift array: {declaration}")


def parse_angle_entries(block: str) -> list[tuple[str, str, str]]:
    pattern = re.compile(
        r"\.init\(\s*route:\s*\.([A-Za-z0-9_]+),\s*"
        r'title:\s*"((?:\\.|[^"\\])*)",\s*'
        r'subtitle:\s*"((?:\\.|[^"\\])*)"',
        re.S,
    )
    return [
        (route, swift_string(title), swift_string(subtitle))
        for route, title, subtitle in pattern.findall(block)
    ]


def parse_theory_entries(source: str) -> list[tuple[str, str, str]]:
    start = source.find("static let entries: [TheoryIndexEntry] = [")
    end = source.find("    /// 按 `TheoryGroup.allCases`", start)
    if start < 0 or end < 0:
        raise ValueError("missing TheoryCatalog.entries")
    block = source[start:end]
    pattern = re.compile(
        r"\.init\(\s*id:\s*\.([A-Za-z0-9_]+),.*?"
        r'title:\s*"((?:\\.|[^"\\])*)",.*?'
        r'subtitle:\s*"((?:\\.|[^"\\])*)",.*?'
        r"isPublished:\s*(true|false)\s*\)",
        re.S,
    )
    return [
        (page_id, swift_string(title), swift_string(subtitle))
        for page_id, title, subtitle, published in pattern.findall(block)
        if published == "true"
    ]


def parse_cover_maps(source: str) -> tuple[dict[str, str], dict[str, str]]:
    route_map = dict(
        re.findall(
            r"case \.([A-Za-z0-9_]+): return \.([A-Za-z0-9_]+)",
            source[source.find("static func coverArt(for route:"):source.find("static func key(for route:")],
        )
    )
    theory_map = dict(
        re.findall(
            r"case \.([A-Za-z0-9_]+): return \.([A-Za-z0-9_]+)",
            source[source.find("static func coverArt(forTheoryPage"):],
        )
    )
    return route_map, theory_map


def display_width(text: str) -> int:
    return sum(2 if unicodedata.east_asian_width(char) in {"W", "F"} else 1 for char in text)


def card_audits() -> list[CardAudit]:
    angle_source = read_text(ANGLE_HOME_PATH)
    theory_source = read_text(THEORY_CATALOG_PATH)
    atmosphere_source = read_text(ATMOSPHERE_PATH)
    route_covers, theory_covers = parse_cover_maps(atmosphere_source)

    section_entries: list[tuple[str, str, str, str, str]] = []
    declarations = (
        ("学", "W18", "learnEntries"),
        ("练", "W20", "trainEntries"),
        ("打", "W21", "basePlayEntries"),
        ("解", "W21", "solveEntries"),
    )
    for section, batch, declaration in declarations:
        for route, title, subtitle in parse_angle_entries(extract_declared_array(angle_source, declaration)):
            section_entries.append((section, batch, route, title, subtitle))
    for page_id, title, subtitle in parse_theory_entries(theory_source):
        section_entries.append(("理", "W19", f"theoryPage({page_id})", title, subtitle))

    grouped: dict[str, list[tuple[str, str, str, str, str]]] = defaultdict(list)
    for item in section_entries:
        grouped[item[0]].append(item)

    audits: list[CardAudit] = []
    for section, batch, route, title, subtitle in section_entries:
        siblings = grouped[section]
        index = siblings.index((section, batch, route, title, subtitle))
        neighbor = siblings[index + 1][3] if index + 1 < len(siblings) else siblings[index - 1][3]
        if route.startswith("theoryPage("):
            page_id = route.removeprefix("theoryPage(").removesuffix(")")
            cover = theory_covers.get(page_id, "缺失")
            source = "TheoryCatalog + 16 理论转写真源"
        else:
            cover = route_covers.get(route, "缺失")
            source = "AngleHomeView + 对应 route 落地页"
        width = display_width(subtitle)
        width_audit = "软风险：建议实机核对" if width > 32 or len(subtitle) > 18 else "待实机核对"
        audits.append(
            CardAudit(
                section=section,
                batch=batch,
                route=route,
                title=title,
                subtitle=subtitle,
                cover_key=cover,
                source=source,
                neighbor_title=neighbor,
                subtitle_length=len(subtitle),
                subtitle_display_width=width,
                width_audit=width_audit,
                status=f"待 {batch}",
            )
        )
    section_order = {"学": 0, "理": 1, "练": 2, "打": 3, "解": 4}
    return sorted(audits, key=lambda item: (section_order[item.section], item.route))


def similarity_pairs(drills: list[DrillAudit]) -> list[dict[str, Any]]:
    by_category: dict[str, list[DrillAudit]] = defaultdict(list)
    for drill in drills:
        by_category[drill.category].append(drill)
    pairs: list[dict[str, Any]] = []
    drill_payload: dict[str, dict[str, Any]] = {}
    for drill in drills:
        data = json.loads(read_text(REPO / drill.path))
        drill_payload[drill.short_id] = data
    for category, items in by_category.items():
        for index, left in enumerate(items):
            for right in items[index + 1:]:
                left_data = drill_payload[left.short_id]
                right_data = drill_payload[right.short_id]
                left_text = normalize_text(
                    [left_data.get("description"), left_data.get("coachingPoints"), left_data.get("standardCriteria")]
                )
                right_text = normalize_text(
                    [right_data.get("description"), right_data.get("coachingPoints"), right_data.get("standardCriteria")]
                )
                ratio = difflib.SequenceMatcher(None, left_text, right_text).ratio()
                if ratio >= 0.58:
                    pairs.append(
                        {
                            "category": category,
                            "left": left.short_id,
                            "right": right.short_id,
                            "ratio": round(ratio, 3),
                        }
                    )
    return sorted(pairs, key=lambda item: (-item["ratio"], item["left"], item["right"]))


def build_report() -> dict[str, Any]:
    drills = drill_audits()
    cards = card_audits()
    all_images = [key for drill in drills for key in drill.image_keys]
    all_sequences = [path for drill in drills for path in drill.sequence_paths]
    repository_sequences = sorted(SEQUENCE_ROOT.glob("drill_*.json"))
    risk_term_counts: Counter[str] = Counter()
    core_phrases: Counter[str] = Counter()
    description_lengths: list[int] = []
    criteria_lengths: list[int] = []
    coaching_lengths: list[int] = []
    empty_core_fields: list[str] = []
    for drill in drills:
        data = json.loads(read_text(REPO / drill.path))
        description = str(data.get("description", "")).strip()
        criteria = str(data.get("standardCriteria", "")).strip()
        coaching = [str(item).strip() for item in (data.get("coachingPoints") or [])]
        description_lengths.append(len(description))
        criteria_lengths.append(len(criteria))
        coaching_lengths.extend(len(item) for item in coaching)
        if not str(data.get("nameZh", "")).strip():
            empty_core_fields.append(f"{drill.short_id}.nameZh")
        if not description:
            empty_core_fields.append(f"{drill.short_id}.description")
        if not coaching or any(not item for item in coaching):
            empty_core_fields.append(f"{drill.short_id}.coachingPoints")
        if not criteria:
            empty_core_fields.append(f"{drill.short_id}.standardCriteria")
        for phrase in [description, *coaching, criteria]:
            if len(phrase) >= 8:
                core_phrases[phrase] += 1
        learner_text = normalize_text(
            [
                data.get("nameZh"),
                data.get("description"),
                data.get("coachingPoints"),
                data.get("standardCriteria"),
                effective_tutorial(data)[1],
            ]
        )
        for term in RISK_TERMS:
            risk_term_counts[term] += learner_text.count(term)
    errors: list[str] = []
    if len(drills) != EXPECTED_DRILLS:
        errors.append(f"expected {EXPECTED_DRILLS} drills, found {len(drills)}")
    if len({drill.short_id for drill in drills}) != len(drills):
        errors.append("duplicate active drill ids")
    if set(BATCH_BY_ID) != {drill.short_id for drill in drills}:
        missing = sorted({drill.short_id for drill in drills} - set(BATCH_BY_ID))
        extra = sorted(set(BATCH_BY_ID) - {drill.short_id for drill in drills})
        errors.append(f"batch map mismatch: missing={missing}, extra={extra}")
    if len(cards) != EXPECTED_CARDS:
        errors.append(f"expected {EXPECTED_CARDS} production cards, found {len(cards)}")
    if any(card.route == "batchDrillStudio" for card in cards):
        errors.append("simulator-only batchDrillStudio leaked into production card inventory")
    for drill in drills:
        if drill.short_id in RULESET_IDS:
            if drill.sequence_paths:
                errors.append(f"{drill.short_id}: ruleset unexpectedly has sequences")
            if drill.tutorial_path != "ruleset.sections":
                errors.append(f"{drill.short_id}: ruleset tutorial path mismatch")
        elif not drill.sequence_paths:
            errors.append(f"{drill.short_id}: non-ruleset has no sequence")
        if drill.missing_master_keys:
            errors.append(f"{drill.short_id}: missing PNG {list(drill.missing_master_keys)}")
        if drill.missing_published_keys:
            errors.append(f"{drill.short_id}: missing HEIC {list(drill.missing_published_keys)}")
    return {
        "generated_from": {
            "index": relative(INDEX_PATH),
            "intent": relative(INTENT_PATH),
            "angle_home": relative(ANGLE_HOME_PATH),
            "theory_catalog": relative(THEORY_CATALOG_PATH),
            "atmosphere": relative(ATMOSPHERE_PATH),
        },
        "counts": {
            "drills": len(drills),
            "cards": len(cards),
            "image_references": len(all_images),
            "unique_image_keys": len(set(all_images)),
            "sequence_files": len(all_sequences),
            "repository_sequence_files": len(repository_sequences),
            "rulesets": sum(drill.short_id in RULESET_IDS for drill in drills),
            "intent_blocked": sum("阻塞" in drill.intent_status for drill in drills),
        },
        "category_counts": dict(Counter(drill.category for drill in drills)),
        "card_section_counts": dict(Counter(card.section for card in cards)),
        "tutorial_path_counts": dict(Counter(drill.tutorial_path for drill in drills)),
        "risk_term_counts": dict(risk_term_counts),
        "field_stats": {
            "empty_core_fields": empty_core_fields,
            "description": {
                "min": min(description_lengths),
                "max": max(description_lengths),
                "average": round(sum(description_lengths) / len(description_lengths), 1),
            },
            "coaching_point": {
                "min": min(coaching_lengths),
                "max": max(coaching_lengths),
                "average": round(sum(coaching_lengths) / len(coaching_lengths), 1),
                "count": len(coaching_lengths),
            },
            "standard_criteria": {
                "min": min(criteria_lengths),
                "max": max(criteria_lengths),
                "average": round(sum(criteria_lengths) / len(criteria_lengths), 1),
            },
        },
        "exact_duplicate_core_phrases": [
            {"count": count, "text": text}
            for text, count in sorted(core_phrases.items(), key=lambda item: (-item[1], item[0]))
            if count > 1
        ],
        "first_coaching_risks": [
            {"id": drill.short_id, "audit": drill.first_coaching_audit, "text": drill.first_coaching}
            for drill in drills
            if drill.first_coaching_audit.startswith("风险")
        ],
        "card_width_risks": [asdict(card) for card in cards if card.width_audit.startswith("软风险")],
        "similarity_pairs": similarity_pairs(drills),
        "drills": [asdict(drill) for drill in drills],
        "cards": [asdict(card) for card in cards],
        "errors": errors,
    }


def markdown_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", "<br>")


def render_markdown(report: dict[str, Any]) -> str:
    counts = report["counts"]
    field_stats = report["field_stats"]
    lines = [
        "# v49 动作库与练习卡文案台账",
        "",
        "> 生成口径：`scripts/audit_billiard_copy_quality.py --format markdown`。",
        "> 本台账骨架由当前仓库机械提取，不生成学习者正文；最小训练命题、冲突结论和 H-11 状态必须在对应批次人工填写。",
        "",
        "## W0 基线摘要",
        "",
        f"- 有效动作：**{counts['drills']}**",
        f"- 练习生产卡：**{counts['cards']}**",
        f"- 有效图片引用：**{counts['image_references']}**（唯一键 {counts['unique_image_keys']}）",
        f"- 现行动作关联序列：**{counts['sequence_files']}**（仓库共 {counts['repository_sequence_files']}，其余属于退役动作）",
        f"- ruleset：**{counts['rulesets']}**（c065 / c068 / c070）",
        f"- 训练意图阻塞：**{counts['intent_blocked']}**（c055）",
        f"- 核心字段空值：**{len(field_stats['empty_core_fields'])}**",
        f"- description 字数：平均 {field_stats['description']['average']}，范围 {field_stats['description']['min']}–{field_stats['description']['max']}",
        f"- coachingPoint：{field_stats['coaching_point']['count']} 条，平均 {field_stats['coaching_point']['average']} 字，范围 {field_stats['coaching_point']['min']}–{field_stats['coaching_point']['max']}",
        f"- standardCriteria 字数：平均 {field_stats['standard_criteria']['average']}，范围 {field_stats['standard_criteria']['min']}–{field_stats['standard_criteria']['max']}",
        "",
        "### 当前风险词计数（软审计，不是全局禁词）",
        "",
        "| 词 | 出现次数 |",
        "|---|---:|",
    ]
    for term, count in report["risk_term_counts"].items():
        lines.append(f"| {markdown_cell(term)} | {count} |")
    lines += [
        "",
        "### W0 已知边界",
        "",
        "- c001 / c011 / c012：现有核心字段是候选样张，尚未完成教程和 H-11 定调。",
        "- c012：旧教程“只拉距离、不换切角”与训练意图及逐杆配图冲突，W1 必须闭环。",
        "- c055：用户训练意图为空，状态明确为“正文阻塞”；AI 不自行补造意图。",
        "- c065 / c068 / c070：无 sequence 的规则课，后续按规则与页面行为取证。",
        "",
        "## 动作台账（74）",
        "",
        "| ID | 批次 | 分类 | 当前名称 | 意图状态 | 教程路径 | 序列 | 图片 | 最小训练命题 | 相邻对照 | core | tutorial | 冲突 | 首要点跨页 | H-11 |",
        "|---|---|---|---|---|---|---:|---:|---|---|---|---|---|---|---|",
    ]
    for drill in report["drills"]:
        lines.append(
            "| {short_id} | {batch} | {category} | {name} | {intent_status} | {tutorial_path} | {sequences} | {images} | {proposition} | {neighbor_id} | {core_status} | {tutorial_status} | {conflict} | {first_audit} | 待本批人工复核 |".format(
                short_id=drill["short_id"],
                batch=drill["batch"],
                category=drill["category"],
                name=markdown_cell(drill["name"]),
                intent_status=markdown_cell(drill["intent_status"]),
                tutorial_path=drill["tutorial_path"],
                sequences=len(drill["sequence_paths"]),
                images=len(drill["image_keys"]),
                proposition=markdown_cell(drill["proposition"]),
                neighbor_id=drill["neighbor_id"],
                core_status=markdown_cell(drill["core_status"]),
                tutorial_status=markdown_cell(drill["tutorial_status"]),
                conflict=markdown_cell(drill["conflict"]),
                first_audit=markdown_cell(drill["first_coaching_audit"]),
            )
        )
    lines += [
        "",
        "## 练习卡台账（36）",
        "",
        "| 区域 | 批次 | route | 当前标题 | 当前副标题 | cover key | 落地页/来源 | 相邻卡 | 字符/显示宽 | 小屏风险 | 状态 | H-11 |",
        "|---|---|---|---|---|---|---|---|---:|---|---|---|",
    ]
    for card in report["cards"]:
        lines.append(
            "| {section} | {batch} | `{route}` | {title} | {subtitle} | `{cover}` | {source} | {neighbor} | {length}/{width} | {width_audit} | {status} | 待本批人工复核 |".format(
                section=card["section"],
                batch=card["batch"],
                route=card["route"],
                title=markdown_cell(card["title"]),
                subtitle=markdown_cell(card["subtitle"]),
                cover=card["cover_key"],
                source=markdown_cell(card["source"]),
                neighbor=markdown_cell(card["neighbor_title"]),
                length=card["subtitle_length"],
                width=card["subtitle_display_width"],
                width_audit=markdown_cell(card["width_audit"]),
                status=card["status"],
            )
        )
    lines += [
        "",
        "## 逐动作证据清单",
        "",
        "> 这里记录有效 tutorial 消费路径对应的 sequence 与 image key。图片“已查看”状态必须在各内容批人工更新，不能由脚本代填。",
        "",
    ]
    for drill in report["drills"]:
        intent_lines = []
        for row in drill["intent_rows"]:
            original = row["original"] or "（空）"
            refined = row["refined"] or "（空）"
            intent_lines.append(
                f"  - {row['formation_index']} {row['formation']}：原文={original}；完善={refined}"
            )
        lines += [
            f"### {drill['short_id']} · {drill['name']} · {drill['batch']}",
            "",
            f"- JSON：`{drill['path']}`",
            f"- 意图：{drill['intent_status']}",
            *(intent_lines or ["  - 意图表无对应行"]),
            f"- 有效教程路径：`tutorial.{drill['tutorial_path']}`",
            f"- sequence（{len(drill['sequence_paths'])}）：" + ("、".join(f"`{item}`" for item in drill["sequence_paths"]) or "无（ruleset 路径）"),
            f"- image keys（{len(drill['image_keys'])}）：" + ("、".join(f"`{item}`" for item in drill["image_keys"]) or "无"),
            "- 图片查看：待本批逐张确认",
            f"- 首条 coaching：{drill['first_coaching'] or '（空）'}",
            f"- 首条跨页审计：{drill['first_coaching_audit']}",
            f"- 风险词：{('、'.join(drill['risk_terms']) if drill['risk_terms'] else '无当前软词命中')}",
            f"- 冲突：{drill['conflict']}",
            "",
        ]
    lines += [
        "## 软审计报告",
        "",
        "### 首条 coaching 结构风险",
        "",
    ]
    if report["first_coaching_risks"]:
        for item in report["first_coaching_risks"]:
            lines.append(f"- {item['id']}：{item['audit']}；原文：{item['text']}")
    else:
        lines.append("- 无机械风险；仍须人工检查可执行性。")
    lines += ["", "### 卡片单行宽度软风险", ""]
    if report["card_width_risks"]:
        for card in report["card_width_risks"]:
            lines.append(
                f"- {card['section']} / {card['title']}：{card['subtitle']}（{card['subtitle_length']} 字，显示宽度 {card['subtitle_display_width']}）"
            )
    else:
        lines.append("- 无机械风险；仍须在目标机型实测。")
    lines += ["", "### 同分类高相似 core 文案（SequenceMatcher ≥ 0.58）", ""]
    if report["similarity_pairs"]:
        for item in report["similarity_pairs"]:
            lines.append(
                f"- {item['category']}：{item['left']} ↔ {item['right']}，相似度 {item['ratio']:.3f}；进入对应批次做相邻互换测试。"
            )
    else:
        lines.append("- 无命中。")
    lines += ["", "### core 字段完全重复句", ""]
    if report["exact_duplicate_core_phrases"]:
        for item in report["exact_duplicate_core_phrases"]:
            lines.append(f"- ×{item['count']}：{item['text']}")
    else:
        lines.append("- 无命中。")
    lines += [
        "",
        "## W0 机械验收",
        "",
        f"- 数量：动作 {counts['drills']} / 卡片 {counts['cards']}。",
        f"- 证据：active sequence {counts['sequence_files']} / repository sequence {counts['repository_sequence_files']} / image references {counts['image_references']}。",
        f"- 缺失或结构错误：{len(report['errors'])}。",
        "- 结论：" + ("W0 机械基线通过。" if not report["errors"] else "存在错误，见下。"),
    ]
    for error in report["errors"]:
        lines.append(f"  - {error}")
    lines += [
        "",
        "## 批次更新规则",
        "",
        "1. 每批先重跑审计，确认范围与证据清单未漂移。",
        "2. 人工查看图片后，把对应动作的“图片查看”改为实际结论；不得批量标已看。",
        "3. 完成正文后更新最小训练命题、core/tutorial、冲突、首要点和 H-11 列。",
        "4. 本文件中的机械统计可重新生成；人工结论不得被重新生成结果覆盖。",
        "",
        "## 版本记录",
        "",
        "| 版本 | 日期 | 变更 |",
        "|---|---|---|",
        "| v1.0 | 2026-08-31 | W0 建立 74 动作、36 卡和逐动作证据清单；c055 明确为正文阻塞。 |",
    ]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--format", choices=("summary", "json", "markdown"), default="summary")
    parser.add_argument("--strict", action="store_true", help="return non-zero when inventory invariants fail")
    args = parser.parse_args()
    try:
        report = build_report()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"AUDIT ERROR: {error}", file=sys.stderr)
        return 2

    if args.format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2))
    elif args.format == "markdown":
        print(render_markdown(report), end="")
    else:
        counts = report["counts"]
        print(
            "COPY AUDIT "
            f"drills={counts['drills']} cards={counts['cards']} "
            f"images={counts['image_references']} unique_images={counts['unique_image_keys']} "
            f"active_sequences={counts['sequence_files']} repository_sequences={counts['repository_sequence_files']} "
            f"rulesets={counts['rulesets']} "
            f"intent_blocked={counts['intent_blocked']} errors={len(report['errors'])}"
        )
        for error in report["errors"]:
            print(f"ERROR: {error}")
    return 1 if args.strict and report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())

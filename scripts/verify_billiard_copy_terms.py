#!/usr/bin/env python3
"""Verify canonical billiards terms in learner-facing Swift and Drill JSON copy."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
SWIFT_ROOT = REPO / "QiuJi"
DRILL_ROOT = REPO / "QiuJi" / "Resources" / "Drills"

FORBIDDEN_TERMS = {
    "切入角": "切球角",
    "塞偏": "挤偏",
}

LEARNER_JSON_FIELDS = {
    "nameZh",
    "description",
    "coachingPoints",
    "standardCriteria",
    "tutorial",
}

STRING_LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')


def term_hits(text: str) -> list[tuple[str, str]]:
    return [
        (term, replacement)
        for term, replacement in FORBIDDEN_TERMS.items()
        if term in text
    ]


def walk_json_text(node: object, location: str) -> list[tuple[str, str]]:
    values: list[tuple[str, str]] = []
    if isinstance(node, str):
        values.append((location, node))
    elif isinstance(node, list):
        for index, item in enumerate(node):
            values.extend(walk_json_text(item, f"{location}[{index}]"))
    elif isinstance(node, dict):
        for key, value in node.items():
            values.extend(walk_json_text(value, f"{location}.{key}"))
    return values


def scan_swift(path: Path) -> list[str]:
    findings: list[str] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.lstrip().startswith("//"):
            continue
        for literal in STRING_LITERAL.findall(line):
            for term, replacement in term_hits(literal):
                findings.append(
                    f"{path.relative_to(REPO)}:{line_number}: “{term}”应为“{replacement}”"
                )
    return findings


def scan_drill(path: Path) -> list[str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    findings: list[str] = []
    for field in LEARNER_JSON_FIELDS:
        if field not in data:
            continue
        for location, text in walk_json_text(data[field], field):
            for term, replacement in term_hits(text):
                findings.append(
                    f"{path.relative_to(REPO)} {location}: “{term}”应为“{replacement}”"
                )
    return findings


def run_scan() -> list[str]:
    findings: list[str] = []
    for path in sorted(SWIFT_ROOT.rglob("*.swift")):
        findings.extend(scan_swift(path))
    for path in sorted(DRILL_ROOT.rglob("drill_c*.json")):
        findings.extend(scan_drill(path))
    return findings


def selftest() -> int:
    assert term_hits("学习切入角") == [("切入角", "切球角")]
    assert term_hits("投掷、塞偏与弧线") == [("塞偏", "挤偏")]
    assert term_hits("切球角、挤偏与投掷") == []

    sample = {"description": "练切入角", "internal": "塞偏"}
    learner_text = walk_json_text(sample["description"], "description")
    assert learner_text == [("description", "练切入角")]
    print("SELFTEST PASS: 错词可检出，标准术语不误伤")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    findings = run_scan()
    if findings:
        print("COPY TERMS FAIL")
        for finding in findings:
            print(f"- {finding}")
        return 1
    print("COPY TERMS PASS: 学员可见 Swift 文案与 Drill 核心字段未发现禁用术语")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

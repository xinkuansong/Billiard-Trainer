#!/usr/bin/env python3
"""Migrate bundled official plans from weeks/sessions to v54 stages/lessons.

The migration is deterministic: IDs depend only on the existing plan/week/day
identity, while display titles are derived from the focused drill names. A JSON
report records semantic counts before and after each converted plan.
"""

from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLANS = ROOT / "QiuJi" / "Resources" / "Plans"
DRILLS = ROOT / "QiuJi" / "Resources" / "Drills"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def drill_names() -> dict[str, str]:
    result: dict[str, str] = {}
    for path in DRILLS.rglob("drill_c*.json"):
        data = load_json(path)
        drill_id = data.get("id")
        name = data.get("nameZh")
        if isinstance(drill_id, str) and isinstance(name, str):
            result[drill_id] = name
    return result


def session_focus_ids(session: dict) -> list[str]:
    preferred = ["focused", "main", "review", "warmup"]
    for phase_type in preferred:
        ids = [
            ref["drillId"]
            for phase in session.get("phases", [])
            if phase.get("type") == phase_type
            for ref in phase.get("drills", [])
            if isinstance(ref.get("drillId"), str)
        ]
        if ids:
            return list(dict.fromkeys(ids))
    return []


def lesson_titles(sessions: list[dict], names: dict[str, str]) -> list[str]:
    bases = []
    for session in sessions:
        ids = session_focus_ids(session)
        bases.append("与".join(names.get(item, item) for item in ids) or "综合训练")
    totals = Counter(bases)
    seen: Counter[str] = Counter()
    titles = []
    for base in bases:
        seen[base] += 1
        if totals[base] == 1:
            titles.append(base)
        elif seen[base] == 1:
            titles.append(f"{base}入门")
        elif seen[base] == totals[base]:
            titles.append(f"{base}检验")
        else:
            titles.append(f"{base}巩固")
    return titles


def semantic_counts(plan: dict) -> dict:
    containers = plan.get("stages")
    if containers is None:
        containers = plan.get("weeks", [])
        child_key = "sessions"
    else:
        child_key = "lessons"
    lessons = [lesson for stage in containers for lesson in stage.get(child_key, [])]
    phases = [phase for lesson in lessons for phase in lesson.get("phases", [])]
    refs = [
        ref.get("drillId")
        for phase in phases
        for ref in phase.get("drills", [])
        if isinstance(ref.get("drillId"), str)
    ]
    return {
        "stageCount": len(containers),
        "lessonCount": len(lessons),
        "phaseCount": len(phases),
        "drillReferenceCount": len(refs),
        "drillReferenceMultiset": dict(sorted(Counter(refs).items())),
    }


def migrate(plan: dict, names: dict[str, str]) -> dict:
    if "stages" in plan:
        raise ValueError(f"{plan.get('id')}: already uses stages")
    plan_id = plan["id"]
    stages = []
    for week in plan["weeks"]:
        sessions = week["sessions"]
        titles = lesson_titles(sessions, names)
        stage_order = week["weekNumber"]
        stage_title = week["theme"].strip()
        stages.append({
            "id": f"{plan_id}.stage{stage_order:02d}",
            "order": stage_order,
            "title": stage_title,
            "goal": f"掌握{stage_title}",
            "lessons": [
                {
                    "id": f"{plan_id}.stage{stage_order:02d}.lesson{session['dayNumber']:02d}",
                    "order": session["dayNumber"],
                    "title": title,
                    "summary": f"围绕{title}完成本课训练。",
                    "phases": session["phases"],
                }
                for session, title in zip(sessions, titles, strict=True)
            ],
        })
    return {
        "id": plan["id"],
        "nameZh": plan["nameZh"],
        "nameEn": plan["nameEn"],
        "targetLevel": plan["targetLevel"],
        "estimatedMinutesPerLesson": plan["minutesPerSession"],
        "isPremium": plan["isPremium"],
        "description": plan["description"],
        "stages": stages,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plans", nargs="+", required=True)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    names = drill_names()
    report = {"schemaVersion": 1, "plans": []}
    for plan_id in args.plans:
        path = PLANS / f"{plan_id}.json"
        before_plan = load_json(path)
        before = semantic_counts(before_plan)
        after_plan = migrate(before_plan, names)
        after = semantic_counts(after_plan)
        if before != after:
            raise SystemExit(f"{plan_id}: semantic count drift: {before} != {after}")
        lesson_ids = [
            lesson["id"]
            for stage in after_plan["stages"]
            for lesson in stage["lessons"]
        ]
        if len(lesson_ids) != len(set(lesson_ids)):
            raise SystemExit(f"{plan_id}: duplicate lesson IDs")
        report["plans"].append({
            "planId": plan_id,
            "before": before,
            "after": after,
            "stageTitles": [stage["title"] for stage in after_plan["stages"]],
            "lessonIds": lesson_ids,
            "lessonTitles": [
                lesson["title"]
                for stage in after_plan["stages"]
                for lesson in stage["lessons"]
            ],
        })
        if args.write:
            path.write_text(
                json.dumps(after_plan, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

    report["totals"] = {
        "planCount": len(report["plans"]),
        "lessonCount": sum(item["after"]["lessonCount"] for item in report["plans"]),
        "phaseCount": sum(item["after"]["phaseCount"] for item in report["plans"]),
        "drillReferenceCount": sum(
            item["after"]["drillReferenceCount"] for item in report["plans"]
        ),
    }
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

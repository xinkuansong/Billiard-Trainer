#!/usr/bin/env python3
"""Verify v54 W0 fixtures and expose the intentional pre-implementation red gate."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "QiuJiTests" / "Fixtures" / "V54"
PLANS = ROOT / "QiuJi" / "Resources" / "Plans"


def load_json(path: Path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def classify(current: int | None, selected: list[int]) -> dict[str, str]:
    unique = set(selected)
    if current is None:
        return {str(value): "review" for value in sorted(unique)}

    prefix_end = current
    while prefix_end in unique:
        prefix_end += 1

    result: dict[str, str] = {}
    for value in sorted(unique):
        if value < current:
            result[str(value)] = "review"
        elif value < prefix_end:
            result[str(value)] = "advanceEligible"
        else:
            result[str(value)] = "preview"
    return result


def settle_case(case: dict) -> tuple[int | None, bool]:
    current = case["currentOrdinal"]
    if current is None:
        return None, True
    if case["activePlanAtCompletion"] != case["planId"]:
        return current, False

    roles = classify(current, case["selectedOrdinals"])
    completed = set(case["completionOrder"])
    eligible = {int(key) for key, value in roles.items() if value == "advanceEligible"}
    cursor = current
    while cursor in eligible and cursor in completed:
        cursor += 1
    if cursor >= case["lessonCount"]:
        return None, True
    return cursor, False


def stable_lesson_id(plan_id: str, week_number: int, day_number: int) -> str:
    return f"{plan_id}.stage{week_number:02d}.lesson{day_number:02d}"


def verify_schedule_cases(errors: list[str]) -> None:
    payload = load_json(FIXTURES / "today-schedule-cases.json")
    required_ids = {
        "review_and_current",
        "current_and_next",
        "current_and_gapped_future",
        "future_only",
        "eligible_completed_in_reverse",
        "active_plan_switched_before_completion",
        "duplicate_completion_callback",
    }
    cases = payload.get("cases", [])
    actual_ids = {case.get("id") for case in cases}
    if missing := required_ids - actual_ids:
        errors.append(f"schedule fixture missing cases: {sorted(missing)}")

    for case in cases:
        roles = classify(case["currentOrdinal"], case["selectedOrdinals"])
        if roles != case["expectedRoles"]:
            errors.append(f"{case['id']}: roles {roles} != {case['expectedRoles']}")
        cursor, completed = settle_case(case)
        if cursor != case["expectedCurrentOrdinal"]:
            errors.append(
                f"{case['id']}: cursor {cursor} != {case['expectedCurrentOrdinal']}"
            )
        if completed != case["expectedCompleted"]:
            errors.append(
                f"{case['id']}: completed {completed} != {case['expectedCompleted']}"
            )
        if case["repeatCompletionCallbacks"] < 1:
            errors.append(f"{case['id']}: repeatCompletionCallbacks must be positive")


def verify_migration_cases(errors: list[str]) -> None:
    payload = load_json(FIXTURES / "legacy-active-plan-cases.json")
    required_ids = {
        "official_only",
        "custom_only",
        "official_and_custom",
        "duplicate_official_latest_wins",
    }
    cases = payload.get("cases", [])
    actual_ids = {case.get("id") for case in cases}
    if missing := required_ids - actual_ids:
        errors.append(f"migration fixture missing cases: {sorted(missing)}")

    for case in cases:
        if case.get("expectedTrainingSessionDelta") != 0:
            errors.append(f"{case['id']}: migration must not create/delete training sessions")
        migration_keys = [
            item["migrationKey"] for item in case.get("expectedTodayItems", [])
        ]
        if len(migration_keys) != len(set(migration_keys)):
            errors.append(f"{case['id']}: duplicate migration keys")
        for row in case.get("legacyRows", []):
            if not row["isCustom"] and row["planId"] == case.get("expectedActivePlanId"):
                expected = stable_lesson_id(
                    row["planId"], row["currentWeek"], row["currentDay"]
                )
                if expected != case.get("expectedCurrentLessonId"):
                    errors.append(
                        f"{case['id']}: stable id {expected} != "
                        f"{case.get('expectedCurrentLessonId')}"
                    )


def verify_plan_baseline(errors: list[str]) -> None:
    baseline = load_json(FIXTURES / "plan-content-baseline.json")
    plan_files = sorted(path for path in PLANS.glob("plan_*.json"))
    actual: dict[str, dict[str, int]] = {}
    all_ids: set[str] = set()
    duplicate_ids: set[str] = set()

    for path in plan_files:
        plan = load_json(path)
        stages = plan.get("stages")
        weeks = plan.get("weeks")
        lesson_count = 0
        stage_count = 0
        if stages is not None:
            stage_count = len(stages)
            for stage in stages:
                for lesson in stage.get("lessons", []):
                    lesson_count += 1
                    lesson_id = lesson.get("id")
                    if lesson_id in all_ids:
                        duplicate_ids.add(lesson_id)
                    all_ids.add(lesson_id)
        else:
            weeks = weeks or []
            stage_count = len(weeks)
            for week in weeks:
                for session in week.get("sessions", []):
                    lesson_count += 1
                    lesson_id = stable_lesson_id(
                        plan["id"], week["weekNumber"], session["dayNumber"]
                    )
                    if lesson_id in all_ids:
                        duplicate_ids.add(lesson_id)
                    all_ids.add(lesson_id)
        actual[plan["id"]] = {
            "stageCount": stage_count,
            "lessonCount": lesson_count,
        }

    if len(actual) != baseline["planCount"]:
        errors.append(f"plan count {len(actual)} != {baseline['planCount']}")
    if sum(value["lessonCount"] for value in actual.values()) != baseline["lessonCount"]:
        errors.append("total lesson count drifted from baseline")
    if actual != baseline["plans"]:
        errors.append(f"per-plan baseline drifted: {actual}")
    if duplicate_ids:
        errors.append(f"duplicate generated lesson ids: {sorted(duplicate_ids)}")


def verify_implementation(errors: list[str]) -> None:
    checks = {
        "PlanStage production type": (
            ROOT / "QiuJi" / "Data" / "Services" / "PlanContentService.swift",
            "struct PlanStage",
        ),
        "PlanLesson production type": (
            ROOT / "QiuJi" / "Data" / "Services" / "PlanContentService.swift",
            "struct PlanLesson",
        ),
        "official lesson cursor": (
            ROOT / "QiuJi" / "Data" / "Models" / "UserActivePlan.swift",
            "currentLessonId",
        ),
    }
    schedule_model = ROOT / "QiuJi" / "Data" / "Models" / "TodayTrainingSchedule.swift"
    if not schedule_model.exists():
        errors.append("implementation missing: TodayTrainingSchedule model")
    for label, (path, token) in checks.items():
        if not path.exists() or token not in path.read_text(encoding="utf-8"):
            errors.append(f"implementation missing: {label}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-implementation", action="store_true")
    args = parser.parse_args()

    errors: list[str] = []
    verify_schedule_cases(errors)
    verify_migration_cases(errors)
    verify_plan_baseline(errors)
    if args.require_implementation:
        verify_implementation(errors)

    if errors:
        for error in errors:
            print(f"[FAIL] {error}")
        return 1
    mode = "implementation" if args.require_implementation else "fixture"
    print(f"[PASS] v54 W0 {mode} contract")
    return 0


if __name__ == "__main__":
    sys.exit(main())

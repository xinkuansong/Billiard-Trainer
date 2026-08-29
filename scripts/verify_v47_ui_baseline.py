#!/usr/bin/env python3
"""Verify problem-set v47 W0 screenshot, route, and write-surface contracts."""

from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / "docs/design/v47"
SCREENSHOT_MANIFEST = DESIGN / "baseline-screenshots.sha256"
ROUTE_COVERAGE = DESIGN / "route-coverage.csv"
ROUTE_SIGNATURES = DESIGN / "route-surface-signatures.sha256"
WRITE_SURFACES = DESIGN / "write-surface-files.txt"

ROUTE_MARKERS = (
    "NavigationLink",
    ".navigationDestination",
    ".sheet(",
    ".fullScreenCover(",
)

REQUIRED_VIEWS = {
    "RootView", "MainTabView", "TrainingHomeView", "PlanListView", "PlanDetailView",
    "CustomPlanBuilderView", "ActiveTrainingView", "DrillRecordView", "TrainingNoteView",
    "TrainingSummaryView", "TrainingShareView", "DrillListView", "FavoriteDrillsView",
    "DrillDetailView", "DrillTutorialView", "AngleHomeView", "HistoryCalendarView",
    "StatisticsView", "TrainingDetailView", "AngleSessionDetailView", "TrainingDataEditorView",
    "ProfileView", "LoginView", "PhoneLoginView", "OnboardingView", "PersonalInfoView",
    "TrainingGoalView", "SettingsView", "AboutView", "SubscriptionView",
    "SubscriptionStatusView", "AimingPrincipleView", "AimingMethodsView",
    "AimingCorrectionView", "SpinAndEnglishView", "SeparationAngleAtlasView",
    "CushionEnglishAtlasView", "AngleDynamicView", "BallFeelView", "ContactPointTableView",
    "TheoryIndexView", "TheoryT01View", "TheoryT02View", "TheoryT03View", "TheoryT04View",
    "TheoryT05View", "TheoryT06View", "TheoryT07View", "TheoryT08View", "TheoryT09View",
    "TheoryT10View", "TheoryFlowView", "TheoryQuickRefView", "GeometricAngleQuizView",
    "SceneAimingView", "AimPointTrainingView", "AimPointSceneTrainingView",
    "ShotSimulationView", "PositionPlayComposerView", "FreePlayView", "BallExtractionView",
    "BatchDrillStudioView", "BatchBallExtractionView", "BatchAuthoringView", "SiluTrainerView",
    "PlanThreeView", "SnookerTacticsView", "BankShotView", "DiamondSystemView",
}


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def parse_hash_manifest(path: Path) -> dict[str, str]:
    rows: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        digest, relative = line.split(maxsplit=1)
        rows[relative] = digest
    return rows


def verify_screenshots() -> int:
    expected = parse_hash_manifest(SCREENSHOT_MANIFEST)
    actual_files = sorted((ROOT / "tmp/designer-screenshots").glob("*.png"))
    if len(expected) != 66 or len(actual_files) != 66:
        fail(f"截图基线必须是 66 张：manifest={len(expected)} actual={len(actual_files)}")
    actual_names = {str(path.relative_to(ROOT)) for path in actual_files}
    if set(expected) != actual_names:
        fail(f"截图文件名差集：missing={sorted(set(expected)-actual_names)} extra={sorted(actual_names-set(expected))}")
    bad = [relative for relative, digest in expected.items() if sha256(ROOT / relative) != digest]
    if bad:
        fail(f"截图哈希漂移：{bad}")
    return len(expected)


def route_source_files() -> list[Path]:
    files: list[Path] = [ROOT / "QiuJi/App/RootView.swift"]
    for base in (ROOT / "QiuJi/App", ROOT / "QiuJi/Features"):
        for path in base.rglob("*.swift"):
            text = path.read_text(encoding="utf-8")
            if any(marker in text for marker in ROUTE_MARKERS):
                files.append(path)
    return sorted(set(files))


def route_signature(path: Path) -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    selected: list[str] = []
    for index, line in enumerate(lines):
        stripped = line.strip()
        is_route_line = any(marker in line for marker in ROUTE_MARKERS)
        is_route_case = bool(re.match(r"case\s+[A-Za-z][A-Za-z0-9_]*(?:\([^)]*\))?$", stripped))
        is_test_link = "args.contains(" in line or "hasPrefix(\"-deeplink" in line
        if is_route_line or is_route_case or is_test_link:
            for follow in lines[index:min(len(lines), index + 7)]:
                normalized = follow.strip()
                if normalized:
                    selected.append(normalized)
    payload = "\n".join(selected).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def current_route_signatures() -> dict[str, str]:
    return {
        str(path.relative_to(ROOT)): route_signature(path)
        for path in route_source_files()
    }


def verify_routes() -> int:
    with ROUTE_COVERAGE.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    required_columns = {"view", "family", "batch", "states", "screenshot", "test", "scope", "source"}
    if not rows or not required_columns.issubset(rows[0]):
        fail(f"route-coverage.csv 缺列：{sorted(required_columns - set(rows[0] if rows else []))}")
    for number, row in enumerate(rows, start=2):
        empty = [column for column in required_columns if not row.get(column, "").strip()]
        if empty:
            fail(f"route-coverage.csv:{number} 空字段：{empty}")
        source = ROOT / row["source"].split(":", 1)[0]
        if not source.is_file():
            fail(f"route-coverage.csv:{number} source 不存在：{source}")
        source_text = source.read_text(encoding="utf-8")
        if not re.search(rf"\bstruct\s+{re.escape(row['view'])}\b", source_text):
            fail(f"route-coverage.csv:{number} source 未声明 {row['view']}：{source}")
    views = {row["view"] for row in rows}
    missing = sorted(REQUIRED_VIEWS - views)
    if missing:
        fail(f"生产/明确豁免页面未登记批次：{missing}")

    expected = parse_hash_manifest(ROUTE_SIGNATURES)
    actual = current_route_signatures()
    if expected != actual:
        fail(
            "路由表层发生漂移；先审计生产可达性并更新 route-coverage.csv 与签名。"
            f" missing={sorted(set(expected)-set(actual))} extra={sorted(set(actual)-set(expected))}"
        )
    return len(rows)


def current_write_surface_files() -> list[str]:
    results: list[str] = []
    patterns = (".write(", "FileManager.default.createDirectory", "pngRepresentation")
    for base in (ROOT / "QiuJiTests", ROOT / "QiuJiUITests"):
        for path in base.rglob("*.swift"):
            text = path.read_text(encoding="utf-8")
            if any(pattern in text for pattern in patterns):
                results.append(str(path.relative_to(ROOT)))
    return sorted(results)


def verify_write_surfaces() -> int:
    stale_gate = ROOT / "build/.run-bake-runners"
    if stale_gate.exists():
        fail("检测到 build/.run-bake-runners；普通 test 前必须移走，避免 bake runner 改写真源")

    expected = [
        line.strip() for line in WRITE_SURFACES.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    ]
    actual = current_write_surface_files()
    if expected != actual:
        fail(
            "测试写盘面发生漂移；先登记输出目录/清理/污染风险。"
            f" missing={sorted(set(expected)-set(actual))} extra={sorted(set(actual)-set(expected))}"
        )

    tour = (ROOT / "QiuJiUITests/ScreenshotTourUITests.swift").read_text(encoding="utf-8")
    if re.search(r'let\s+base\s*=.*docs/ui-polish/screenshots-latest', tour):
        fail("ScreenshotTour 默认路径仍指向 docs/ui-polish/screenshots-latest")
    if re.search(r"try\?[^\n]*(?:pngRepresentation|createDirectory)", tour):
        fail("ScreenshotTour 仍用 try? 静默吞截图写盘失败")
    if "assertV47BaselineScreenshotCompleteness" not in tour:
        fail("ScreenshotTour 缺 v47 预期截图完整性门禁")
    if "v47ForcedShotDirURL" not in tour or "guard resetV47ShotDirectory() else { return }" not in tour:
        fail("完整 v47 巡游未隔离旧截图目录，或目录校验失败后仍会继续写盘")
    return len(actual)


def print_route_signatures() -> None:
    for relative, digest in current_route_signatures().items():
        print(f"{digest}  {relative}")


def print_write_surfaces() -> None:
    print("\n".join(current_write_surface_files()))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--print-route-signatures", action="store_true")
    parser.add_argument("--print-write-surfaces", action="store_true")
    args = parser.parse_args()
    if args.print_route_signatures:
        print_route_signatures()
        return 0
    if args.print_write_surfaces:
        print_write_surfaces()
        return 0

    screenshots = verify_screenshots()
    routes = verify_routes()
    writes = verify_write_surfaces()
    print(f"[v47 UI 基线] screenshots={screenshots} routes={routes} write-surfaces={writes} FAIL=0")
    return 0


if __name__ == "__main__":
    sys.exit(main())

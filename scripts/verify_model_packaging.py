#!/usr/bin/env python3
"""Keep retired model originals out of generated projects and built Apps."""
import argparse
import json
from pathlib import Path
import re

CURRENT = ("ModelTrial20261010_TaiQiuZhuo.usdz", "ModelTrial20261010_CueUV.usdz")
LEGACY = ("TaiQiuZhuo.usdz", "CueUV.usdz")


def config_problems(spec: str, pbx: str) -> list[str]:
    problems = []
    active = "\n".join(line for line in spec.splitlines() if not line.lstrip().startswith("#"))
    for exclusion in ("Resources/TaiQiuZhuo.usdz", "Resources/LegacyModels/**"):
        if not re.search(r'^\s*-\s*"' + re.escape(exclusion) + r'"\s*$', active, re.M):
            problems.append(f"project.yml missing exclusion: {exclusion}")
    for path in re.findall(r'^\s*-\s*path:\s*(\S+)\s*$', active, re.M):
        if path == "QiuJi/Resources" or path.startswith("QiuJi/Resources/LegacyModels") or Path(path).name in LEGACY:
            problems.append(f"project.yml reintroduces retired resources: {path}")
    for name in (*LEGACY, "LegacyModels"):
        if f"/* {name} in Resources */" in pbx:
            problems.append(f"project.pbxproj packages retired resource: {name}")
    for name in CURRENT:
        if f"/* {name} in Resources */" not in pbx:
            problems.append(f"project.pbxproj missing production resource: {name}")
    return problems


def bundle_problems(bundle: Path) -> list[str]:
    problems = []
    for name in CURRENT:
        if not (bundle / name).is_file():
            problems.append(f"App missing production model: {name}")
    for path in bundle.rglob("*"):
        if path.name in LEGACY or path.name == "LegacyModels":
            problems.append(f"App contains retired model: {path.relative_to(bundle)}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--bundle", type=Path)
    args = parser.parse_args()
    problems = config_problems((args.root / "project.yml").read_text(),
                               (args.root / "QiuJi.xcodeproj/project.pbxproj").read_text())
    if (args.root / "QiuJi/Resources/CueStyles/CueUV.usdz").exists():
        problems.append("Retired CueUV.usdz is inside the packaged CueStyles folder")
    if args.bundle:
        problems.extend(bundle_problems(args.bundle))
    print(json.dumps({"passed": not problems, "bundle": str(args.bundle) if args.bundle else None,
                      "problems": problems}, ensure_ascii=False))
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Keep retired model originals out of generated projects and built Apps."""
import argparse
import json
from pathlib import Path
import re
import zipfile

CURRENT = ("ModelTrial20261010_TaiQiuZhuo.usdz", "ModelTrial20261010_CueUV.usdz")
LEGACY = ("TaiQiuZhuo.usdz", "CueUV.usdz")


def attribute_problems(attributes: str) -> list[str]:
    lines = {tuple(line.split()) for line in attributes.splitlines()}
    return [f".gitattributes missing LFS rule: CuePhys/Resources/{name}"
            for name in (*CURRENT, "TaiQiuZhuo.usdz")
            if (f"CuePhys/Resources/{name}", "filter=lfs", "diff=lfs", "merge=lfs", "-text") not in lines]


def model_problems(path: Path) -> list[str]:
    if not path.is_file():
        return [f"Missing production model: {path}"]
    try:
        with path.open("rb") as stream:
            if stream.read(200).startswith(b"version https://git-lfs.github.com/spec/v1"):
                return [f"Unresolved Git LFS pointer: {path}; restore the model with git lfs checkout/pull"]
        with zipfile.ZipFile(path) as archive:
            if not any(Path(name).suffix in (".usd", ".usda", ".usdc") for name in archive.namelist()):
                return [f"USDZ contains no USD scene: {path}"]
            corrupt = archive.testzip()
            if corrupt:
                return [f"USDZ CRC failure: {path}: {corrupt}"]
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError, NotImplementedError) as error:
        return [f"Invalid USDZ: {path}: {error}"]
    return []


def config_problems(spec: str, pbx: str) -> list[str]:
    problems = []
    active = "\n".join(line for line in spec.splitlines() if not line.lstrip().startswith("#"))
    for exclusion in ("Resources/TaiQiuZhuo.usdz", "Resources/LegacyModels/**"):
        if not re.search(r'^\s*-\s*"' + re.escape(exclusion) + r'"\s*$', active, re.M):
            problems.append(f"project.yml missing exclusion: {exclusion}")
    for path in re.findall(r'^\s*-\s*path:\s*(\S+)\s*$', active, re.M):
        if path == "CuePhys/Resources" or path.startswith("CuePhys/Resources/LegacyModels") or Path(path).name in LEGACY:
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
        problems.extend(model_problems(bundle / name))
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
                               (args.root / "CuePhys.xcodeproj/project.pbxproj").read_text())
    problems.extend(attribute_problems((args.root / ".gitattributes").read_text()))
    for name in CURRENT:
        problems.extend(model_problems(args.root / "CuePhys/Resources" / name))
    if (args.root / "CuePhys/Resources/CueStyles/CueUV.usdz").exists():
        problems.append("Retired CueUV.usdz is inside the packaged CueStyles folder")
    if args.bundle:
        problems.extend(bundle_problems(args.bundle))
    print(json.dumps({"passed": not problems, "bundle": str(args.bundle) if args.bundle else None,
                      "problems": problems}, ensure_ascii=False))
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())

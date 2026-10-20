#!/usr/bin/env python3
"""Offline bank request, source fingerprint, and coverage audit; never claims no solution."""
import argparse
import collections
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "output/accuracy-practice-20261020"


def sources():
    files = set((ROOT / "QiuJi/Core/Physics").glob("*.swift"))
    files.update(ROOT / name for name in [
        "QiuJi/Core/Scene/AngleSceneCalculator.swift",
        "QiuJi/Features/AngleTraining/SceneTrainingRules.swift",
        "QiuJi/Core/Training/TrainingQuestionBank.swift",
        "QiuJi/Core/Scene/CueStick.swift",
        "QiuJi/Core/Scene/CueStroke.swift",
        "QiuJi/Core/Geometry/AimWheelGain.swift",
        "QiuJi/Core/Components/AdaptiveShotDrag.swift",
        "QiuJiTests/TrainingQuestionBankTests.swift",
        "QiuJiTests/TrainingBankProductionTests.swift",
        "QiuJiTests/TrainingBankExpansionTests.swift",
        "QiuJiTests/TrainingBankCartesianSupport.swift",
        "QiuJiTests/TrainingBankCartesianTests.swift",
        "QiuJiTests/TrainingLayoutDiversityTests.swift",
        "QiuJiTests/SceneTrainingRulesTests.swift",
        "QiuJiTests/TrainingQuestionBankRefinementTests.swift",
    ])
    values = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}
    return {"fingerprint": hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest(), "files": values}


def report(bank):
    boards = {b["id"]: b for b in bank["boards"]}
    variants = bank["variants"]
    def band(angle):
        return next(label for lo, hi, label in [(0,10,"straight"),(11,30,"small"),(31,50,"medium"),(51,70,"large"),(71,85,"thin")] if lo <= round(angle) <= hi)
    def tally(items, key):
        return dict(sorted(collections.Counter(key(item) for item in items).items()))
    return {
        "source_matches_current": bank["sourceFingerprint"] == sources()["fingerprint"],
        "boards": len(boards), "proofs": len(bank["proofs"]), "variants": len(variants),
        "unique_variant_boards": len({v["boardID"] for v in variants}),
        "base_angle": tally(boards.values(), lambda b: band(b["angle"])),
        "base_pocket": tally(boards.values(), lambda b: str(b["pocketIndex"])),
        "base_distances": tally(boards.values(), lambda b: b["cueBand"]+"/"+b["pocketBand"]),
        "accuracy_angle_tip": tally(variants, lambda v: band(boards[v["boardID"]]["angle"])+"/"+v["tip"]),
        "accuracy_pocket": tally(variants, lambda v: str(boards[v["boardID"]]["pocketIndex"])),
        "note": "Counts are coverage evidence, not proof every filter combination can form a batch. Run Swift sampler validation before release.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    request = sub.add_parser("request")
    request.add_argument("--count", type=int, default=300)
    request.add_argument("--seed", type=int, default=20261020)
    check = sub.add_parser("report")
    check.add_argument("bank", type=Path)
    production = sub.add_parser("production")
    production.add_argument("--thin", type=int, default=20)
    production.add_argument("--frozen", type=int, default=20)
    production.add_argument("--distances", type=int, default=0)
    expansion = sub.add_parser("expand", help="Resume stratified, symmetry-deduplicated production")
    expansion.add_argument("--minimum", type=int, default=3000)
    expansion.add_argument("--seed", type=int, default=202610201)
    expansion.add_argument("--resume", action="store_true")
    cartesian = sub.add_parser("cartesian", help="270 independent cells, 500 families/cell; compact saved solutions")
    cartesian.add_argument("--seed", type=int, default=20261021)
    cartesian.add_argument("--workers", type=int, default=4)
    cartesian.add_argument("--seconds", type=float, default=240)
    cartesian.add_argument("--attempts-per-cell", type=int, default=2000)
    cartesian.add_argument("--cells", nargs="*", default=[])
    cartesian.add_argument("--resume", action="store_true")
    cartesian.add_argument("--revalidate", action="store_true", help="Replay saved inputs and all nine samples before continuing")
    sub.add_parser("verify", help="Fail if the bundled bank is missing, changed or stale")
    publish = sub.add_parser("publish", help="Package an actually revalidated bank and its coverage evidence")
    publish.add_argument("bank", type=Path)
    publish.add_argument("--coverage", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "request":
        if not 1 <= args.count <= 1000 or not 0 <= args.seed < 2**64:
            parser.error("count must be 1...1000; seed must be UInt64")
        OUTPUT.mkdir(parents=True, exist_ok=True)
        manifest = sources()
        (OUTPUT / "source-manifest.json").write_text(json.dumps(manifest, indent=2))
        (OUTPUT / "generator-request.json").write_text(json.dumps({
            "count": args.count, "seed": args.seed, "sourceFingerprint": manifest["fingerprint"]}))
        print("Prepared one-use request. Run TrainingQuestionBankTests/testGenerateOfflinePilot through the simulator lifecycle.")
    elif args.command == "production":
        if not all(0 <= n <= 100 for n in (args.thin, args.frozen, args.distances)):
            parser.error("supplement counts must be 0...100")
        OUTPUT.mkdir(parents=True, exist_ok=True)
        manifest = sources()
        (OUTPUT / "production-source-manifest.json").write_text(json.dumps(manifest, indent=2))
        (OUTPUT / "production-request.json").write_text(json.dumps({
            "sourceFingerprint": manifest["fingerprint"], "addThin": args.thin, "addFrozen": args.frozen, "addDistances": args.distances}))
        print("Prepared revalidation of every prior nominal proof and stable neighbourhood, then targeted supplements.")
    elif args.command == "cartesian":
        if args.revalidate and not args.resume:
            parser.error("--revalidate requires --resume")
        if not 1 <= args.workers <= 8 or not 0 < args.seconds <= 43200 or not 0 <= args.seed < 2**64 or args.attempts_per_cell < 1:
            parser.error("workers 1...8; seconds (0,43200]; seed UInt64; attempts-per-cell positive")
        valid_cells = {f"a{a}-p{p}-c{c}-o{o}-r{r}" for a in range(5) for p in range(2)
                       for c in range(3) for o in range(3) for r in range(3)}
        if set(args.cells) - valid_cells:
            parser.error("Unknown cell ID")
        directory = ROOT / "output/accuracy-bank-cartesian-20261021"
        directory.mkdir(parents=True, exist_ok=True)
        manifest = sources()
        for path in sorted((directory / "shards").glob("*.json")):
            shard = json.loads(path.read_text())
            if not args.resume:
                parser.error("Existing shards require --resume; never overwrite a prior production run")
            if shard["seed"] != args.seed:
                parser.error(f"Seed changed in {path.name}; use a separate production directory")
            if shard["sourceFingerprint"] != manifest["fingerprint"] and not args.revalidate:
                parser.error(f"Stale shard {path.name}: use --resume --revalidate to actually replay saved solutions")
        request_path = directory / "request.json"
        if request_path.exists():
            parser.error("Unconsumed request exists; inspect it before replacing")
        manifest_path = directory / "source-manifest.json"
        if manifest_path.exists() and args.revalidate:
            previous = manifest_path.read_bytes()
            history = directory / "revalidation-history"
            history.mkdir(exist_ok=True)
            (history / (hashlib.sha256(previous).hexdigest()+"-manifest.json")).write_bytes(previous)
        manifest_path.write_text(json.dumps(manifest, indent=2))
        request_path.write_text(json.dumps({
            "sourceFingerprint": manifest["fingerprint"], "seed": args.seed, "targetPerCell": 500,
            "attemptsPerCell": args.attempts_per_cell, "workers": args.workers,
            "seconds": args.seconds, "resume": args.resume, "revalidate": args.revalidate,
            "cellIDs": args.cells}, indent=2))
        print("Prepared Cartesian request. Run TrainingBankCartesianTests/testProduceCartesianShards. "
              "Time budget checkpoints work; candidate-bank.json is not a published bank.")
    elif args.command == "expand":
        if not 300 <= args.minimum <= 5000 or not 0 <= args.seed < 2**64:
            parser.error("minimum must be 300...5000; seed must be UInt64")
        directory = ROOT / "output/accuracy-bank-expansion-20261020"
        directory.mkdir(parents=True, exist_ok=True)
        manifest = sources()
        if args.resume:
            previous = json.loads((directory / "checkpoint.json").read_text())
            if previous["bank"]["sourceFingerprint"] != manifest["fingerprint"]:
                parser.error("Checkpoint sources changed; full replay required before resuming")
        (directory / "source-manifest.json").write_text(json.dumps(manifest, indent=2))
        (directory / "request.json").write_text(json.dumps({
            "sourceFingerprint": manifest["fingerprint"], "minimumBoards": args.minimum,
            "seed": args.seed, "resume": args.resume}))
        print("Prepared one-use stratified expansion request; run TrainingBankExpansionTests.")
    elif args.command == "report":
        print(json.dumps(report(json.loads(args.bank.read_text())), indent=2, ensure_ascii=False))
    elif args.command == "publish":
        bank = json.loads(args.bank.read_text())
        coverage = json.loads(args.coverage.read_text())
        if bank["sourceFingerprint"] != sources()["fingerprint"]:
            parser.error("Sources changed since validation; replay the proofs before publishing")
        required = [f"{rail}:vertical={v},side={s}" for rail in ("random", "near", "frozen") for v in ("false", "true") for s in ("false", "true")]
        if not all(coverage.get(k) == "10 seeds passed" for k in required):
            parser.error("All twelve rail/tip configurations must pass before packaging")
        payload = json.dumps(bank, separators=(",", ":"), ensure_ascii=False).encode()
        destination = ROOT / "QiuJi/Resources"
        (destination / "training-question-bank.json").write_bytes(payload)
        manifest = {"schemaVersion": 1, "sourceFingerprint": bank["sourceFingerprint"],
                    "contentSHA256": hashlib.sha256(payload).hexdigest(), "sources": sources()["files"],
                    "coverage": coverage, "counts": report(bank)}
        (destination / "training-question-bank-manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
        print("Packaged bank; coverage gaps remain explicit in the manifest.")
    elif args.command == "verify":
        from verify_grid_bank import verify
        verify()



if __name__ == "__main__":
    main()

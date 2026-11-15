"""Summarize retained native experiments; never reruns rendering."""
from pathlib import Path
import hashlib
import json
import statistics

ROOT = Path(__file__).resolve().parents[3]
RUNS = [
    ("H1-pipeline", "742344ccc10c4ab286152b4e7735cd54"),
    ("H2-R1-f32", "39277eee7f9448a1bcf9cd449db5af0f"),
    ("H2-R2-f16", "1315061231a74276a016899c139dffe6"),
    ("H2-R3-compact", "c9c12930b3ae426385aa782be4393096"),
    ("H3-split", "74c2899c8cc5446fa0514466cb298ec2"),
    ("H1-direct", "42cd63b06f5e4b6783a098dbc4d0353a"),
    ("H1-direct-marker", "bc69f7d6a93140babad8f02b980ffbf1"),
    ("H4-short-axis", "368d7c2cd2824461936ed385aafdc513"),
    ("H5-ablation", "bffa4e8124ff4d0a96a38a2f4e336305"),
]


def timing(rows, kind, metric):
    cycles = []
    for cycle in range(6):
        arms = {}
        for arm in ("A", "B"):
            samples = [v for r in rows if r["kind"] == kind
                       and r["cycle"] == cycle and r["arm"] == arm
                       for v in r[metric]]
            assert len(samples) == 24
            arms[arm] = statistics.mean(samples)
        cycles.append({"cycle": cycle, "A_MS": arms["A"], "B_MS": arms["B"],
                       "changePercent": (arms["B"] / arms["A"] - 1) * 100})
    return {
        "pairedMedianChangePercent": statistics.median(r["changePercent"] for r in cycles),
        "medianA_MS": statistics.median(r["A_MS"] for r in cycles),
        "medianB_MS": statistics.median(r["B_MS"] for r in cycles),
        "cycles": cycles,
    }


report = {"date": "2026-11-14", "newProductionCandidateAdopted": False,
          "baseline": "existing default C1; B1/B2 unchanged",
          "scope": "native macOS actual table material; not full App, iPhone or energy",
          "runs": []}
identities = []
for name, run_id in RUNS:
    run = ROOT / "output/local-test-runs" / run_id
    evidence = run / "evidence"
    state = json.loads((run / "run.json").read_text())
    assert state["state"] == "reclaimed" and state["exit_code"] == 0
    for file, digest in state["evidence_sha256"].items():
        assert hashlib.sha256((evidence / file).read_bytes()).hexdigest() == digest, file
    identity = json.loads((evidence / "source-identity.json").read_text())
    identities.append(identity)
    item = {"round": name, "runID": run_id, "state": state["state"],
            "evidence": str(evidence.relative_to(ROOT)), "cases": []}
    for r in json.loads((evidence / "results.json").read_text()):
        case = {key: r[key] for key in ("pose", "width", "variant", "diagnosticOnly", "diagnostics") if key in r}
        case["maximumChannelDifference"] = r["maximumChannelDifference"]
        case["maximumAAChannelDifference"] = max(c["aa"]["maximumChannelDifference"] for c in r["comparisons"])
        case["comparedStates"] = len(r["comparisons"])
        if r["times"]:
            case["timing"] = {metric: {kind: timing(r["times"], kind, metric) for kind in ("AA", "AB")}
                              for metric in ("gpuMS", "cpuEncodeMS", "wallMS")}
        item["cases"].append(case)
    if (evidence / "resources.json").exists():
        item["resources"] = json.loads((evidence / "resources.json").read_text())
    report["runs"].append(item)
assert all(i == identities[0] for i in identities)
for file, digest in identities[0].items():
    assert hashlib.sha256((ROOT / file).read_bytes()).hexdigest() == digest, file
report["allRunSourceIdentitiesEqualAndStillCurrent"] = True
report["allRetainedEvidenceHashesVerified"] = True
report["sourceIdentity"] = identities[0]
destination = ROOT / "tasks/render-highlight-20261114/results.json"
destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(f"{len(RUNS)} reclaimed runs; source identities and evidence hashes verified; {destination}")

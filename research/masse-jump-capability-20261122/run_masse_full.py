#!/usr/bin/env python3
"""Durable full-pool orchestration of the unchanged CB01 masse solver."""
import argparse
import copy
import fcntl
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time
from types import SimpleNamespace

import run_masse_search as search
from analyze_masse_search import candidate

HERE = Path(__file__).resolve().parent
REQUEST = HERE / "masse-full-request-20261126.json"
POINTER = HERE / "masse-full-current.json"
PILOT = HERE / "evidence/masse-search-20261126-2f039520f0b4"


def paths():
    request = json.loads(REQUEST.read_text())
    out = HERE / "evidence" / ("masse-search-20261126-" + request["runIdentity"][:12])
    return request, out


def audit(out, request):
    """Stream the same independent candidate checks used for the first 60."""
    lookup = {s["sampleIndex"]: s for s in request["shapes"]}
    accepted, review = 0, []
    temporary = out / "question-candidates.jsonl.tmp"
    with temporary.open("w") as export:
        for packet in sorted((out / "shapes").glob("*.json.gz")):
            with gzip.open(packet, "rt") as stream:
                row = json.load(stream)
            search.validate(row, lookup[row["sampleIndex"]], request["runIdentity"])
            if row["status"] != "solved":
                continue
            try:
                q = candidate(row, request)
            except (AssertionError, StopIteration, IndexError) as error:
                # Preserve questionable packets, but never include them in the bank export.
                review.append({"sampleIndex": row["sampleIndex"], "reason": str(error) or type(error).__name__})
                continue
            export.write(json.dumps(q, ensure_ascii=False, separators=(",", ":")) + "\n")
            accepted += 1
    temporary.replace(out / "question-candidates.jsonl")
    result = {"acceptedCandidates": accepted, "reviewRequired": review, "runIdentity": request["runIdentity"]}
    search.atomic(out / "candidate-audit.json", result)
    return result


def prepare():
    old = json.loads((PILOT / "manifest.json").read_text())
    assert old["researchSwiftSHA256"] == search.sha(HERE / "MasseSearch.swift")
    assert old["sourceSampleSHA256"] == search.sha(search.source.INPUT)
    assert old["sourceBankSHA256"] == search.sha(search.source.BANK)
    pool = sorted(search.source.read_plans(), key=lambda s: s["sampleIndex"])
    assert len(pool) == 10000 and len({s["sampleIndex"] for s in pool}) == 10000
    bank = json.loads(search.source.BANK.read_text())
    for shape in pool:
        shape["pocketCenter"] = bank["geometry"]["pockets"][shape["pocket"]]["center"]
        positions = [o for o in search.source.obstacle_candidates(shape) if not o["failures"]]
        positions.sort(key=lambda o: o != shape["obstacle"])
        assert positions
        shape["obstacleCandidates"] = positions
    request = {k: copy.deepcopy(v) for k,v in old.items() if k not in ("runIdentity", "shapes", "sampling")}
    request.update(shapes=pool, sampling="all 10000 fixed base shapes, sampleIndex order; no resampling",
                   reusedPilotRunIdentity=old["runIdentity"])
    request["runIdentity"] = hashlib.sha256(json.dumps(request, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    search.atomic(REQUEST, request)
    _, out = paths()
    (out / "shapes").mkdir(parents=True, exist_ok=True)
    search.atomic(out / "manifest.json", request)
    search.atomic(POINTER, {"evidence": str(out), "request": str(REQUEST), "runIdentity": request["runIdentity"]})
    old_lookup = {s["sampleIndex"]: s for s in old["shapes"]}
    lookup = {s["sampleIndex"]: s for s in pool}
    provenance = []
    for packet in sorted((PILOT / "shapes").glob("*.json.gz")):
        with gzip.open(packet, "rt") as stream:
            row = json.load(stream)
        index = row["sampleIndex"]
        search.validate(row, old_lookup[index], old["runIdentity"])
        assert row["source"] == lookup[index] and request["parameters"] == old["parameters"]
        provenance.append({"sampleIndex": index, "packet": str(packet), "sha256": search.sha(packet)})
        row["reusedFrom"] = {"runIdentity": old["runIdentity"], "packetSHA256": search.sha(packet)}
        row["runIdentity"] = request["runIdentity"]
        target = out / "shapes" / packet.name
        if target.exists():
            with gzip.open(target, "rt") as stream:
                assert json.load(stream) == row
        else:
            with gzip.open(target.with_suffix(".tmp"), "wt") as stream:
                json.dump(row, stream, separators=(",", ":"))
            target.with_suffix(".tmp").replace(target)
    assert len(provenance) == 60
    search.atomic(out / "reused-pilot-packets.json", provenance)
    summary = search.summarize(out, request)
    result = audit(out, request)
    print(json.dumps({"evidence": str(out), "summary": summary, "audit": result}), flush=True)


def publish(out, state):
    state["updatedAt"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    search.atomic(out / "job-state.json", state)


def work(args):
    request, out = paths()
    assert os.environ.get("QIUJI_SIMULATOR_LEASE_TOKEN")
    assert os.environ.get("QIUJI_TEST_WORK") == str(args.work)
    assert request["sourceSampleSHA256"] == search.sha(search.source.INPUT)
    assert request["sourceBankSHA256"] == search.sha(search.source.BANK)
    state = {"status": "preparingRuntime", "pid": os.getpid(), "udid": args.udid,
             "runIdentity": request["runIdentity"], "startedAtEpoch": time.time(),
             "work": str(args.work), "lifecycleEvidence": str(args.evidence), "batchSize": args.batch_size}
    lock = (HERE / "masse-full.lock").open("a+")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    publish(out, state)
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    try:
        if shutil.disk_usage(HERE).free < 20*1024**3:
            raise RuntimeError("Less than 20 GiB available; checkpoint preserved")
        # APFS clone isolates all mutable signing/input files from subsequent builds.
        products = args.work / "Products"
        subprocess.run(["cp", "-cR", str(search.PRODUCTS), str(products)], check=True)
        search.PRODUCTS = products
        search.APP = products / "Debug-iphonesimulator/球迹.app"
        search.BUNDLE = search.APP / "PlugIns/QiuJiTests.xctest"
        snapshots = out / "sources"
        snapshots.mkdir(exist_ok=True)
        for name in ("MasseSearch.swift", "run_masse_search.py", "run_masse_full.py", "analyze_masse_search.py", "masse-build-20261126.json", "masse-engine-audit-20261126.json"):
            shutil.copyfile(HERE / name, snapshots / name)
        search.atomic(out / "source-snapshot-sha256.json", {p.name: search.sha(p) for p in snapshots.iterdir()})
        search.atomic(out / "runtime.json", {"products": str(products), "binaryUUID": subprocess.check_output(
            ["xcrun", "dwarfdump", "--uuid", str(search.BUNDLE / "QiuJiTests")], text=True).split()[1]})
        consecutive_failures = 0
        while True:
            summary = search.summarize(out, request)
            checked = audit(out, request)
            state.update(summary=summary, candidateAudit=checked)
            if summary["pending"] == 0:
                state["status"] = "complete"
                publish(out, state)
                search.atomic(args.evidence / "full-run-result.json", state)
                return
            if shutil.disk_usage(HERE).free < 20*1024**3:
                raise RuntimeError("Less than 20 GiB available; checkpoint preserved")
            state["status"] = "running"
            publish(out, state)
            # Validate one new 20-shape batch before the steady 100-shape batches.
            size = 20 if summary["completed"] == 60 else args.batch_size
            run_args = SimpleNamespace(udid=args.udid, request=REQUEST, pointer=POINTER,
                                       count=10000, batch_size=size, max_batches=1)
            existing_logs = set(out.glob("batch-*.log"))
            try:
                search.run(run_args)
            except AssertionError as error:
                new_logs = set(out.glob("batch-*.log")) - existing_logs
                startup = any("Simulator device failed to launch" in p.read_text() for p in new_logs)
                consecutive_failures += 1
                state.update(status="retryingStartup" if startup else "failed", lastError=str(error), consecutiveFailures=consecutive_failures)
                publish(out, state)
                if not startup or consecutive_failures >= 3:
                    raise
                time.sleep(5)
                continue
            consecutive_failures = 0
    except BaseException as error:
        state.update(status="interrupted" if isinstance(error, KeyboardInterrupt) else "failed", lastError=repr(error))
        publish(out, state)
        search.atomic(args.evidence / "full-run-result.json", state)
        raise
    finally:
        fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("command", choices=("prepare", "work", "status"))
    p.add_argument("--udid")
    p.add_argument("--work", type=Path)
    p.add_argument("--evidence", type=Path)
    p.add_argument("--batch-size", type=int, default=100)
    args = p.parse_args()
    if args.command == "prepare":
        with (HERE / "masse-full.lock").open("a+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            prepare()
    elif args.command == "work":
        work(args)
    else:
        _, out = paths()
        state = json.loads((out / "job-state.json").read_text()) if (out / "job-state.json").exists() else {"status": "prepared"}
        state["savedPacketsNow"] = len(list((out / "shapes").glob("*.json.gz")))
        print(json.dumps(state, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

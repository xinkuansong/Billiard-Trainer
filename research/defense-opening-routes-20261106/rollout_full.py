"""Run all quick searches before deeper fallback, with one checkpoint per role layout."""
import json
import sqlite3
import time
from pathlib import Path

def prepare_all(source, out, roles, digest):
    with sqlite3.connect(f"file:{source}/opening-decisions.sqlite3?mode=ro", uri=True) as db:
        db.execute("ATTACH DATABASE ? AS initial", (f"file:{source}/inputs.sqlite3?mode=ro",))
        rows = db.execute("""SELECT c.id,c.kind,g.points FROM candidates c
            JOIN initial.geom g ON g.id=c.geom WHERE c.category IN ('hard','closed')""")
        questions = []
        for source_id, kind, points in rows:
            cue, *objects = json.loads(points)
            numbers = roles[kind]
            label = "Q" + digest(source_id)[:20]
            questions.append(dict(id=label, sampleID=label, sourceFormationID=source_id, kind=kind, cue=cue,
                ownBallNumber=numbers[0], opponentBallNumber=numbers[1], references=[],
                balls=[dict(number=n, position=p) for n,p in zip(numbers, objects, strict=True)]))
    assert len({q["id"] for q in questions}) == len(questions) == 39717
    questions.sort(key=lambda q:q["id"])
    (out/"inputs.json").write_text(json.dumps(questions, separators=(",",":")))

def run_all(controller, questions, uid, binary, identity):
    out = controller.OUT
    start = time.time()
    # Same binary, same 24 geometry/role fixtures as the accepted pilot.
    reference = out.parent
    fixtures = json.loads((reference/"inputs.json").read_text())
    expected = json.loads((reference/"review.json").read_text())["questions"]
    checked = controller.phase("validation",fixtures,uid,binary,identity)
    for row in expected:
        assert not (row["kept"]>=2 and not checked[row["id"]]["admitted"]), row["id"]
    # Reproduce the exact prior full-map scores where fallback requested a map.
    import gzip
    for q in fixtures:
        path = q["id"] + ".json.gz"
        old = json.loads(gzip.decompress((reference/"pilot"/"records"/path).read_bytes()))["record"]["scan"]
        new = json.loads(gzip.decompress((out/"validation"/"records"/path).read_bytes()))["record"]["scan"]
        if not new.get("deferred"):
            assert all(a.get("score")==b.get("score") for a,b in zip(old["rows"],new["rows"],strict=True)),q["id"]
    controller.atomic(out/"validation.json",dict(passed=True,cases=len(checked),multi=sum(x["admitted"] for x in checked.values())))
    manifests = []
    for stage in ("quick", "deep"):
        queue = questions if stage == "quick" else unresolved
        unresolved = []
        verified = 0
        for index in range(0, len(queue), 256):
            name = f"{stage}-{index//256:04d}"
            batch = queue[index:index+256]
            controller.atomic(out/"full-status.json",dict(stage=stage,wave=name,stageTotal=len(queue),
                stageCompleted=index,admittedThisStage=verified,startedAt=start,updatedAt=time.time()))
            checked = controller.phase(name,batch,uid,binary,identity)
            admitted = []
            for q in batch:
                row = checked[q["id"]]
                if row["admitted"]:
                    admitted.append(dict(id=q["id"],routes=row["retained"],record=f"{name}/records/{q['id']}.json.gz"))
                else:
                    unresolved.append(q)
            part = f"{name}/admitted.json"
            controller.atomic(out/part, admitted)
            manifests.append(part)
            verified += len(admitted)
            controller.atomic(out/"parts.json", dict(identity=identity,shards=manifests,complete=False))
        controller.atomic(out/f"{stage}-summary.json",dict(processed=len(queue),admitted=verified,
            remaining=len(unresolved),remainingIDs=[q["id"] for q in unresolved]))
    controller.atomic(out/"parts.json",dict(identity=identity,shards=manifests,complete=True))
    controller.atomic(out/"full-status.json",dict(stage="complete",total=len(questions),
        admitted=len(questions)-len(unresolved),remaining=len(unresolved),finishedAt=time.time()))

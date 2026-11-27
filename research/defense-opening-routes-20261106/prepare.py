import hashlib
import json
import sqlite3
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/"output"/HERE.name/"parallel-limit-v1"
SOURCE=ROOT/"output/defense-opening-choice-20261106"
roles={"two_black":[8,9],"two_own":[1,8],"three":[1,9,8]}
def digest(name):
    return hashlib.sha256(("opening-routes-v1/"+name).encode()).hexdigest()

def prepare():
    OUT.mkdir(parents=True,exist_ok=True)
    db=sqlite3.connect(f"file:{SOURCE}/opening-decisions.sqlite3?mode=ro",uri=True)
    db.row_factory=sqlite3.Row
    db.execute("ATTACH DATABASE ? AS initial",(f"file:{SOURCE}/inputs.sqlite3?mode=ro",))
    count=db.execute("SELECT count(*) FROM candidates WHERE category IN ('hard','closed')").fetchone()[0]
    assert count==39717
    used=set()
    questions=[]
    origins={}
    for kind,numbers in roles.items():
        for tag in ("hard","closed"):
            rows=db.execute("""SELECT c.id,c.geom,c.difficulty,g.points FROM candidates c
                            JOIN initial.geom g ON g.id=c.geom WHERE c.kind=? AND c.category=?""",(kind,tag))
            selected=0
            for row in sorted(rows,key=lambda r:digest(r["id"])):
                if row["geom"] in used:
                    continue
                used.add(row["geom"])
                pts=json.loads(row["points"])
                assert len(pts)==len(numbers)+1
                label=f"S{len(questions)+1:02d}"
                q=dict(id=label,sourceFormationID=row["id"],sampleID=label,kind=kind,cue=pts[0],
                       ownBallNumber=numbers[0],opponentBallNumber=numbers[1],references=[],
                       balls=[dict(number=n,position=p) for n,p in zip(numbers,pts[1:])])
                questions.append(q)
                origins[label]=dict(role=row["id"],geom=row["geom"],category=tag,openingDifficulty=row["difficulty"])
                selected+=1
                if selected==4: break
            assert selected==4
    db.close()
    for name,value in [("inputs",questions),("origins",origins)]:
        (OUT/(name+".json")).write_text(json.dumps(value,ensure_ascii=False,indent=2))
if __name__=="__main__": prepare()

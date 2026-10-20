#!/usr/bin/env python3
"""Independent cross-shard geometry/compact-proof audit (does not replay physics)."""
import argparse
import csv
import hashlib
import itertools
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT = ROOT / "output/accuracy-bank-cartesian-20261021"
CONTACT = 4 * 2**-23


def rail_class(gap):
    return 2 if abs(gap) <= CONTACT else 1 if gap <= .1 + CONTACT else 0


def distance(a,b):
    return math.hypot(a[0]-b[0],a[1]-b[1])


def rail_gap(point, rails, radius):
    candidates=[]
    for i,rail in enumerate(rails):
        a=rail["start"]; b=rail["end"]
        dx=b["x"]-a["x"]; dz=b["z"]-a["z"]
        t=max(0,min(1,((point[0]-a["x"])*dx+(point[1]-a["z"])*dz)/(dx*dx+dz*dz)))
        candidates.append((distance(point,(a["x"]+t*dx,a["z"]+t*dz))-radius,i))
    return min(candidates)


def features(board, geometry, sx=1, sz=1):
    cue=(board["cue"]["x"]*sx,board["cue"]["z"]*sz)
    target=(board["target"]["x"]*sx,board["target"]["z"]*sz)
    aim=(board["effectiveAim"]["x"]*sx,board["effectiveAim"]["z"]*sz)
    pocket=geometry["pockets"][board["pocketIndex"]]
    p=min(range(6),key=lambda i:distance((geometry["pockets"][i]["x"],geometry["pockets"][i]["z"]),(pocket["x"]*sx,pocket["z"]*sz)))
    dx=aim[0]-target[0]; dz=aim[1]-target[1]; length=math.hypot(dx,dz)
    if not length or not all(math.isfinite(v) for v in (*cue,*target,*aim)):
        raise ValueError("Invalid geometry")
    ghost=(target[0]-2*geometry["radius"]*dx/length,target[1]-2*geometry["radius"]*dz/length)
    ix=ghost[0]-cue[0]; iz=ghost[1]-cue[1]
    tg,tr=rail_gap(target,geometry["rails"],geometry["radius"])
    cg,cr=rail_gap(cue,geometry["rails"],geometry["radius"])
    return dict(pocketIndex=p,cueX=cue[0],cueZ=cue[1],targetX=target[0],targetZ=target[1],
                signedCut=math.degrees(math.atan2(ix*dz-iz*dx,ix*dx+iz*dz)),
                entryBearing=math.degrees(math.atan2(dz,dx)),cueDistance=distance(cue,target),
                objectDistance=length,targetGap=tg,cueGap=cg,targetRail=tr,cueRail=cr)


def angular(a,b):
    return abs((a-b+180)%360-180)


def near(a,b):
    if a["pocketIndex"]!=b["pocketIndex"] or any(rail_class(a[k])!=rail_class(b[k]) for k in ("targetGap","cueGap")):
        return False
    limit=.35 if max(abs(a["signedCut"]),abs(b["signedCut"]))>=71 else .75
    if angular(a["signedCut"],b["signedCut"])>limit or angular(a["entryBearing"],b["entryBearing"])>1:
        return False
    for key in ("cueDistance","objectDistance"):
        if abs(a[key]-b[key])>min(.03,.03*min(a[key],b[key])):return False
    for kind in ("cue","target"):
        if distance((a[kind+"X"],a[kind+"Z"]),(b[kind+"X"],b[kind+"Z"]))>.04:return False
        if rail_class(a[kind+"Gap"])!=0:
            if a[kind+"Rail"]!=b[kind+"Rail"] or abs(a[kind+"Gap"]-b[kind+"Gap"])>(.01 if kind=="target" else .015):return False
    return True


class Index:
    def __init__(self,geometry):
        self.geometry=geometry
        self.buckets={}

    def duplicate(self,b):
        for sx,sz in ((1,1),(-1,1),(1,-1),(-1,-1)):
            f=features(b,self.geometry,sx,sz); x=math.floor(f["targetX"]/.04);z=math.floor(f["targetZ"]/.04)
            for dx,dz in itertools.product(range(-1,2),repeat=2):
                for identity,old in self.buckets.get((f["pocketIndex"],x+dx,z+dz),[]):
                    if near(f,old):return identity
        return None

    def add(self,b):
        f=features(b,self.geometry)
        self.buckets.setdefault((f["pocketIndex"],math.floor(f["targetX"]/.04),math.floor(f["targetZ"]/.04)),[]).append((b["id"],f))


def selfcheck(geometry):
    for pair in geometry["pairs"]:
        for key,native in (("a","featuresA"),("b","featuresB")):
            f=features(pair[key],geometry)
            for field in f:
                if field.endswith("Rail"):continue # a tie can select either equidistant rail
                if abs(f[field]-pair[native][field])>1e-3:
                    raise AssertionError(f"Native/Python feature mismatch: {pair['title']} {field}")
        index=Index(geometry);index.add(pair["a"])
        assert (index.duplicate(pair["b"]) is not None)==pair["sameFamily"],pair["title"]


def audit(directory,geometry):
    manifest=json.loads((directory/"source-manifest.json").read_text())
    index=Index(geometry);rows=[];duplicates=[];all_boards=set();proofs=0;files={}
    runtime_fingerprints=set();proof_ids=set();fast_proofs=0
    bands=["short","middle","long"]
    ranges=[(0,10),(11,30),(31,50),(51,70),(71,85)]
    for a,p,c,o,r in itertools.product(range(5),range(2),range(3),range(3),range(3)):
        cell=f"a{a}-p{p}-c{c}-o{o}-r{r}"; path=directory/"shards"/(cell+".json")
        row=dict(cell=cell,target=500,accepted=0,attempts=0,geometryMisses=0,proofMisses=0,duplicates=0,status="not_attempted")
        if path.exists():
            payload=path.read_bytes();s=json.loads(payload);files[path.name]=hashlib.sha256(payload).hexdigest()
            assert s["sourceFingerprint"]==manifest["fingerprint"],"stale shard"
            assert s["cell"]==dict(angleIndex=a,pocketType=p,cueIndex=c,objectIndex=o,railIndex=r)
            assert s["dedupVersion"]==geometry["ruleVersion"]
            assert s.get("runtimeFingerprint"),"missing rendered cue profile binding; revalidate"
            runtime_fingerprints.add(s["runtimeFingerprint"])
            fast_proofs+=s.get("fastProofs") or 0
            row.update({k:s[k] for k in ("attempts","geometryMisses","proofMisses","duplicates")})
            by_id={b["id"]:b for b in s["boards"]}
            assert len(by_id)==len(s["boards"])<=500
            assert not (set(by_id)&all_boards),"duplicate ID"
            all_boards.update(by_id)
            qualified=set()
            for proof in s["proofs"]:
                assert proof["id"] not in proof_ids,"duplicate proof ID"
                proof_ids.add(proof["id"])
                assert proof["boardID"] in by_id
                assert proof["settled"] and proof["specifiedPocket"] and proof["outcome"]=="success"
                assert len(proof["samples"])==9 and all(v["outcome"]=="success" for v in proof["samples"])
                grid={(round(v["angleDeltaDegrees"],5),round(v["velocityDelta"],5)) for v in proof["samples"]}
                assert grid==set(itertools.product((-.025,0,.025),(-.05,0,.05)))
                assert abs(proof["directionRadiusDegrees"]-.025)<1e-7 and abs(proof["velocityRadius"]-.05)<1e-7
                assert abs(math.hypot(proof["direction"]["x"],proof["direction"]["z"])-1)<1e-5
                assert 0<proof["velocity"]<=10
                assert not any(k in proof for k in ("cuePath","targetPath","frames","trajectory","trajectoryFrames"))
                assert any(e.get("ball")=="object" and e.get("pocketID")==f'pocket_{by_id[proof["boardID"]]["pocketIndex"]}' for e in proof["events"])
                qualified.add(proof["boardID"]);proofs+=1
            assert qualified==set(by_id),"unproven board"
            for b in s["boards"]:
                f=features(b,geometry)
                assert ranges[a][0]<=round(b["angle"])<=ranges[a][1]
                assert (b["pocketIndex"]>=4)==bool(p) and b["cueBand"]==bands[c] and b["pocketBand"]==bands[o]
                assert abs(abs(f["signedCut"])-b["angle"])<.05
                assert rail_class(f["targetGap"])==r and f["targetGap"]>=-CONTACT
                for n,key,lower in ((c,"cueDistance",.3),(o,"objectDistance",.25)):
                    lo,hi=[(lower,.6),(.600001,1.2),(1.200001,1.8)][n]
                    assert lo-1e-6<=f[key]<=hi+1e-6
                duplicate=index.duplicate(b)
                if duplicate:duplicates.append([b["id"],duplicate])
                index.add(b)
            row["accepted"]=len(by_id)
            row["status"]="target_reached" if len(by_id)==500 else "partial" if row["attempts"] else "not_attempted"
            assert row["attempts"]==row["accepted"]+row["geometryMisses"]+row["proofMisses"]+row["duplicates"]
        rows.append(row)
    assert len(runtime_fingerprints)==1,"mixed rendered cue profiles"
    report=dict(targetPerCell=500,cells=270,theoreticalTarget=135000,accepted=len(all_boards),proofs=proofs,
                fastProposalProofs=fast_proofs,runtimeFingerprint=next(iter(runtime_fingerprints)),
                cellsAttempted=sum(v["attempts"]>0 for v in rows),cellsOccupied=sum(v["accepted"]>0 for v in rows),
                fullCells=sum(v["accepted"]==500 for v in rows),attempts=sum(v["attempts"] for v in rows),
                crossCellDuplicates=duplicates,sourceFingerprint=manifest["fingerprint"],shardSHA256=files,
                note="Independent geometry/serialized-proof audit only; physics success comes from native producer. Finite misses do not prove impossibility. No frames saved. Not published.")
    (directory/"audit.json").write_text(json.dumps(report,ensure_ascii=False,indent=2))
    with (directory/"distribution.csv").open("w") as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    assert not duplicates,"cross-cell near duplicate"
    print(json.dumps({k:v for k,v in report.items() if k not in ("shardSHA256","sourceFingerprint")},ensure_ascii=False,indent=2))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory",type=Path,default=DEFAULT)
    parser.add_argument("--selfcheck-only",action="store_true")
    args=parser.parse_args()
    geometry=json.loads((ROOT/"output/accuracy-dedup-review-20261021/review.json").read_text())
    selfcheck(geometry)
    print(f"Native/Python agreement: {len(geometry['pairs'])} review pairs")
    if not args.selfcheck_only:audit(args.directory,geometry)


if __name__=="__main__":main()

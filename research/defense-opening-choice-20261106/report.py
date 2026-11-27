"""Audit same-route geometry and classify the initial shooter's direct attacks."""
import gzip
import json
import math
from pathlib import Path
import sqlite3
import struct

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/defense-opening-choice-20261106"
EASY_MAX, HARD_MIN = 40, 70
CATEGORIES = ["attack", "hard", "closed", "middle", "review", "escape"]
NAMES = dict(attack="有明确进攻机会", hard="直进困难", closed="六袋直进均封闭",
             middle="中间档", review="几何待确认", escape="我方目标球完全被挡")
def rounded(x):
    return struct.unpack("f", struct.pack("f", x))[0]

def classify(row, points):
    if row["snookered"]:
        assert not row["pockets"]
        return "escape", None, None, None, None, None, 0
    assert [p["index"] for p in row["pockets"]] == list(range(6))
    best, closed, uncertain = None, 0, 0
    cue, ball = [[rounded(x) for x in point] for point in points[:2]]
    diameter = 2 * rounded(.028575)
    for p in row["pockets"]:
        closed += p["closed"]
        known = p.get("bestKnown")
        if (not known and not p["closed"]) or p.get("estimated"):
            uncertain |= 1 << p["index"]
        if not known:
            continue
        assert not p["closed"] and known["pocket"] == p["index"]
        ax, az = (a-b for a,b in zip(known["aim"],ball))
        length = math.hypot(ax,az)
        ux, uz = ax/length, az/length
        vx, vz = ball[0]-diameter*ux-cue[0], ball[1]-diameter*uz-cue[1]
        angle = math.degrees(math.atan2(abs(vx*uz-vz*ux),vx*ux+vz*uz))
        assert abs(angle-known["cutDegrees"]) < 1e-6
        width = known["rightDegrees"]-known["leftDegrees"]
        comfort = known["comfort"]
        score = 100*math.sqrt((1-comfort/100)/(1+5*width*math.cos(math.radians(angle))**2))
        assert 0 <= score <= 100 and 0 <= angle <= 90 and width >= 0
        candidate = (score, p["index"], width, comfort, angle)
        if best is None or candidate < best:
            best = candidate
    if not row["reliable"]:
        tag = "review"
    elif best and best[0] <= EASY_MAX:
        tag = "attack"
    elif closed == 6:
        tag = "closed"
    elif uncertain or best is None:
        tag = "review"
    elif best[0] >= HARD_MIN:
        tag = "hard"
    else:
        tag = "middle"
    return (tag, *(best or (None,)*5), uncertain)

def main():
    temp = OUT/"decisions.tmp"
    temp.unlink(missing_ok=True)
    db = sqlite3.connect(temp)
    db.execute("ATTACH DATABASE ? AS source",(f"file:{OUT}/inputs.sqlite3?mode=ro",))
    db.execute("CREATE TABLE decisions(geom INTEGER PRIMARY KEY, category TEXT, difficulty REAL, pocket INTEGER, width REAL, comfort REAL, cut REAL, unresolvedMask INTEGER)")
    cursor=iter(db.execute("SELECT id,points FROM source.geom ORDER BY id"))
    for archive in sorted(OUT.glob("pockets-*.jsonl.gz")):
        rows=[]
        with gzip.open(archive) as stream:
            for line in stream:
                row=json.loads(line)
                index,points=next(cursor)
                assert row["id"]==index
                rows.append((index,*classify(row,json.loads(points))))
        db.executemany("INSERT INTO decisions VALUES(?,?,?,?,?,?,?,?)",rows)
    assert next(cursor,None) is None
    db.execute("CREATE TABLE candidates AS SELECT m.id,m.kind,d.* FROM source.members m JOIN decisions d ON m.geom=d.geom")
    db.execute("CREATE INDEX candidates_category ON candidates(kind,category)")
    assert db.execute("SELECT COUNT(*) FROM candidates").fetchone()[0]==516478
    groups={}
    for kind,tag,n in db.execute("SELECT kind,category,COUNT(*) FROM candidates GROUP BY kind,category"):
        groups.setdefault(kind,{key:0 for key in CATEGORIES})[tag]=n
    comparison = {}
    for threshold in (60,65,70,75,80,85):
        comparison[threshold] = dict(db.execute("SELECT kind,COUNT(*) FROM candidates WHERE category='closed' OR (category IN ('hard','middle') AND difficulty>=?) GROUP BY kind",(threshold,)))
    db.commit()
    db.close()
    (OUT/"decisions.tmp").replace(OUT/"opening-decisions.sqlite3")
    (OUT/"summary.json").write_text(json.dumps(dict(groups=groups, thresholdComparison=comparison, easyMax=EASY_MAX,hardMin=HARD_MIN),ensure_ascii=False,indent=2))
    lines=["# 起杆时我方是否值得防守", "",
           "输入为20 cm分组的516,478个代表球形。按起杆母球、我方合法首碰球和所有其他球的实际位置，使用生产六袋进球和瞄准管道，以及同路线舒适分和λ5公式。取六袋中最小难度。两种两球球权共享相同的几何评估，保留独立题目身份。", "",
           "暂用≤40作为明确进攻见证，≥70作为直进困难线，以便审阅分布。确认六袋直进均封闭的单独统计。对难攻、中间档要求各袋均有已知路线或封闭证据，任何估算和未解决袋口单列。存在已确认的容易路线即可优先进攻。母球直线完全无法碰到我方球归解球类。", "",
           "|球权|"+"|".join(NAMES[k] for k in CATEGORIES)+"|","|---|"+"---:|"*len(CATEGORIES)]
    for kind,title in [("two_black","我方8／对方9"),("two_own","我方1／对方8"),("three","我方1／对方9／静止8")]:
        lines.append("|"+title+"|"+"|".join(f"{groups[kind][k]:,}" for k in CATEGORIES)+"|")
    lines+=["","## 难攻门槛的影响","", "计入可复核的难攻和六袋封闭两类。", "",
            "|难攻下限|我方8／对方9|我方1／对方8|三球|","|---|---:|---:|---:|"]
    for t,c in comparison.items():
        lines.append(f"|{t}|"+"|".join(f"{c.get(k,0):,}" for k in ("two_black","two_own","three"))+"|")
    lines+=["","[代表球形示例](opening-examples.png)","","候选表保存在 opening-decisions.sqlite3 的 candidates 表。每条初始角色 ID 可追溯最佳袋口、评分、容错宽度、舒适分、切角及待确认袋口位掩码。逐袋证据按原始几何编号保存在 pockets-*.jsonl.gz。这里评的是单杆直接进攻难度，防守打法可达性和打进后的胜负收益需要后续判断。"]
    (OUT/"README.md").write_text("\n".join(lines)+"\n")
    print(json.dumps(groups))
if __name__=="__main__": main()

"""Six examples that distinguish an opening attack decision from its defensive outcome."""
import gzip
import json
from pathlib import Path
import sqlite3
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/"output"/HERE.name
sys.path.insert(0,str(ROOT/"research/defense-threshold-comparison-20261105"))
import geometric_table as g
import matplotlib.pyplot as plt

db=sqlite3.connect(f"file:{OUT}/opening-decisions.sqlite3?mode=ro",uri=True)
db.row_factory=sqlite3.Row
db.execute("ATTACH DATABASE ? AS source",(f"file:{OUT}/inputs.sqlite3?mode=ro",))
fig,axes=plt.subplots(3,2,figsize=(13.4,12))
fig.patch.set_facecolor("#f4f5ef")
fig.subplots_adjust(left=.035,right=.97,top=.91,bottom=.05,wspace=.05,hspace=.43)
selected=[]
for i,(category,title,focus) in enumerate([("attack","优先进攻",25),("hard","难攻，可考虑防守",75),("closed","六袋直进均封闭",0)]):
    for j,(kind,balls,role) in enumerate([("two_black",[0,8,9],"我方 8"),("three",[0,1,9,8],"我方 1，静止 8")]):
        ax=axes[i,j]
        item=db.execute("""SELECT * FROM candidates WHERE category=? AND kind=?
                         ORDER BY abs(coalesce(difficulty,0)-?), geom LIMIT 1""",(category,kind,focus)).fetchone()
        if not item:
            ax.axis("off")
            ax.text(.05,.5,"此组没有符合该档的代表题",transform=ax.transAxes)
            continue
        points=json.loads(db.execute("SELECT points FROM source.geom WHERE id=?",(item["geom"],)).fetchone()[0])
        first=item["geom"]//2048*2048
        with gzip.open(OUT/f"pockets-{first:06}.jsonl.gz") as stream:
            record=next(x for x in map(json.loads,stream) if x["id"]==item["geom"])
        g.table(ax)
        if item["pocket"] is not None:
            route=record["pockets"][item["pocket"]]["bestKnown"]
            import numpy as np
            target=np.array(points[1]);aim=np.array(route["aim"])
            ghost=target-2*g.R*(aim-target)/np.linalg.norm(aim-target)
            ax.plot([points[0][0],ghost[0]],[points[0][1],ghost[1]],color="white",lw=1,zorder=6)
            ax.plot([target[0],aim[0]],[target[1],aim[1]],color="#ffcf69",ls="--",lw=1.2,zorder=6)
        for pos,n in zip(points,balls):g.ball(ax,pos,n)
        ax.set_title(f"{role}  ·  {title}",loc="left",fontsize=15,color="#163d36")
        if item["difficulty"] is None:
            caption="全部直接进袋线路受阻"
        else:
            caption=f'最佳袋难度 {item["difficulty"]:.1f}   切角 {item["cut"]:.1f}°   容错角 {item["width"]:.3f}°   舒适分 {item["comfort"]:.1f}'
        ax.text(.01,-.06,caption,transform=ax.transAxes,color="#355e52")
        selected.append(dict(item))
fig.text(.035,.962,"起杆时，我方这一球该不该攻？",fontsize=22,color="#163d36")
fig.savefig(OUT/"opening-examples.png",dpi=135,facecolor=fig.get_facecolor())
plt.close(fig)
(OUT/"example-ids.json").write_text(json.dumps(selected,ensure_ascii=False,indent=2))

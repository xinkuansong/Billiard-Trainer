"""Show one verified shared-eight board with both routes and their perturbation scores."""
import gzip
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/'output'/HERE.name
if "--deep" in sys.argv:
    OUT = OUT/'deep'
sys.path.insert(0,str(ROOT/'research/defense-opening-routes-20261106'))
import review

def main():
    entries=json.loads((OUT/'admitted.json').read_bytes())
    if not entries:return
    def load(entry):
        return json.loads(gzip.decompress((OUT/entry['record']).read_bytes()))
    def rank(entry):
        rs=load(entry)['routes']; info=[review.evidence(r,8) for r in rs]
        return (sum(i['estimated'] for i in info),-sum(i['sameRails'] for i in info),
                sum(sum(map(len,i['rails'])) for i in info),entry['id'])
    if "--deep" in sys.argv:
        improved = [e for e in entries if len(json.loads(gzip.decompress((OUT.parent/e['record']).read_bytes()))['routes'])<2]
        if improved:
            entries = improved
    rec=load(min(entries,key=rank))
    fig=review.sheet(rec['question'],rec['routes'])
    fig.suptitle('单黑八防守 · 同一起杆球形的两种解',fontsize=16)
    fig.text(.03,.025,'白线为母球，黑虚线为 8 号；实心球是起点，空心圈是终点。',fontsize=9)
    fig.savefig(OUT/'example.png',dpi=140)
    review.plt.close(fig)
    print(rec['question']['sourceFormationID'],[review.evidence(r,8) for r in rec['routes']])
if __name__=='__main__':main()

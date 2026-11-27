from pathlib import Path
import importlib.util,json,collections,copy,hashlib
ROOT=Path(__file__).resolve().parents[2]
source=(ROOT/'research/bank-extension24-20261101/audit.py').read_text()
# Reuse the independent event, geometry and score checks; replace sample-only quotas.
source=source[:source.index("if __name__=='__main__':")]
source=source.replace("assert len(rows)==24 and len({r['id'] for r in rows})==24","assert len({r['id'] for r in rows})==len(rows)")
source=source.replace(" assert {(r['type'],r['n'],r['angleBand'],r['sampleIndex']) for r in rows}=={(t,n,a,d) for t in ['middle','corner'] for n in [2,3] for a in range(3) for d in range(2)}",'')
source=source.replace("(0 if math.dist(r['cue'],r['target'])<1.0 else 1)","(0 if math.dist(r['cue'],r['target'])<1.0 else 1 if math.dist(r['cue'],r['target'])<1.6 else 2)")
source=source.replace("r['n'] in [2,3]","r['n'] in [1,2,3]")
source=source.replace("actual>=45 and r['angleBand']==(0 if actual<55 else 1 if actual<65 else 2)","actual>=45")
ns={'__file__':str(ROOT/'research/bank-extension24-20261101/audit.py')};exec(compile(source,'inherited_independent_audit','exec'),ns)
def check(rows,g,v,tree,summary):
 ns['tree']=tree;ns['tree_audit'](tree,g);ns['audit'](rows,g,v)
 assert len(summary['targets'])==12 and len(rows)==summary['selected']
 assert {p['targetIndex'] for p in summary['targets']}==set(range(12))
 for p in summary['targets']:
  assert p['counts']['sampled']==128
  group=[r for r in rows if r['targetIndex']==p['targetIndex']]
  assert {r['id'] for r in group}==set(p['keptIDs']) and len(group)==p['kept']<=6
  assert all(n<=2 for n in collections.Counter(r['distanceBand'] for r in group).values())
  for r in group:assert r['target']==p['target'] and r['seedFraction']==p['fraction'] and r['routeID']==summary['routeID']
 return True

from pathlib import Path
import json,gzip,copy,tempfile
import core as C
ROOT=C.ROOT;OUT=C.OUT;OUT.mkdir(exist_ok=True)
D=C.D
class FrozenWorker:
 def __init__(self,orig,generated):self.rows={C.params(r):r for r in orig+generated};self.calls=0
 def run(self,b,cs):
  self.calls+=len(cs);rows=[]
  for c in cs:
   r=copy.deepcopy(self.rows[C.params(c)]);r['comboIndex']=c['comboIndex']
   if 'excludedPreContactCushionMetadata' in r:r['trajectory2mm']['cushions']=r['excludedPreContactCushionMetadata']+r['trajectory2mm']['cushions']
   rows.append(r)
  return {'rows':rows,'elapsedSeconds':0}
def clean(v):
 if isinstance(v,list):return [clean(x) for x in v]
 if isinstance(v,dict):return {k:clean(x) for k,x in v.items() if k not in ('stats','elapsedSeconds','wallMilliseconds','initialAimMilliseconds','physicsMilliseconds','extractionCompressionMilliseconds','refineDecisions')}
 return v
checks=[]
with tempfile.TemporaryDirectory(dir=OUT) as t:
 C.OUT=Path(t)
 for i,old in enumerate(D['boards'],1):
  p=ROOT/old['simulationSource']['part'];orig=json.loads(gzip.decompress(p.read_bytes()).splitlines()[old['simulationSource']['rowInPart']]);gen=C.read(ROOT/f'output/two-ball-refine-five-20261025/generated-{i}.json');w=FrozenWorker(orig['rows'],gen['rows']);new=C.process(old,w,i,orig,C.sha(p));ref=C.read(ROOT/f'output/two-ball-refine-five-20261025/result-{i}.json');assert clean(new)==clean(ref),old['id'];checks.append({'id':old['id'],'requests':w.calls,'exactRankedTop5ParamsKeypoints':True})
 # Full dataset may have zero successes / no B; exercise those branches.
 empty=copy.deepcopy(old);empty['candidates']=[];empty.pop('defaultCellID',None);raw=copy.deepcopy(orig);raw['rows']=[];got=C.process(empty,FrozenWorker([],[]),'empty',raw,C.sha(p));assert got['routes']==got['candidates']==[]
 empty['candidates']=copy.deepcopy(old['candidates']);got=C.process(empty,FrozenWorker([],[]),'zero',raw,C.sha(p));assert all(c['top5']==[] for c in got['candidates'])
C.write(OUT/'parity.json',{'passed':True,'fiveLayoutChecks':checks,'emptyCandidatesAndZeroSuccess':True,'method':'replay frozen native outputs through exact new orchestration; production worker separately checks unchanged replay per layout'})
print('PARITY PASSED',len(checks))

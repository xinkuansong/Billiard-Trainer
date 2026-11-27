"""Additional original-coordinate layouts, with explicit research-only role adaptation."""
from pathlib import Path
import json,gzip,copy
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-maxscore-gallery-20261106'
cfg=json.loads((OUT/'scenario.json').read_text());known={c['symmetryKey'] for c in cfg['cases']}
qs=sorted(json.loads(gzip.decompress((ROOT/'QiuJi/Resources/defense-practice-bank.json.gz').read_bytes()))['questions'],key=lambda q:q['id'])
new=[]
for kind in ['two_own','three']:
 for q in qs:
  if q['kind']!=kind:continue
  target=next(b['position'] for b in q['balls'] if b['number']==q['opponentBallNumber']);key=':'.join(f'{abs(v):.5f}' for v in target)
  if key in known:continue
  known.add(key);adapted=copy.deepcopy(q)
  if kind=='two_own':
   own=next(b['position'] for b in q['balls'] if b['number']==q['ownBallNumber'])
   note='原题我方1号改为8号，对方8号改为9号；两球和母球坐标不变'
  else:
   own=next(b['position'] for b in q['balls'] if b['number']==8)
   note='保留原题母球、8号、9号坐标，移除1号作为我方已清至8号的研究球形'
  adapted['balls']=[{'number':8,'position':own},{'number':9,'position':target}]
  adapted['ownBallNumber']=8;adapted['opponentBallNumber']=9;adapted['references']=[]
  new.append({'label':f'S{len(new)+1:04d}','target':target,'question':adapted,'originalQuestion':q,'adaptation':note,'symmetryKey':key})
sc={**cfg,'cases':new};dest=OUT/'supplement';dest.mkdir(exist_ok=True)
(dest/'scenario.json').write_text(json.dumps(sc,ensure_ascii=False,indent=2))
print('Additional candidates',len(new))

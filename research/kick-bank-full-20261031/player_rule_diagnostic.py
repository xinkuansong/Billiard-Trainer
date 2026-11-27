"""Diagnose the current post-contact cushion rule, never filter bank membership."""
from pathlib import Path
import gzip,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/kick-bank-full-20261031'
a=json.loads((OUT/'audit.json').read_text());index=json.loads((OUT/'bank-index.json').read_text());byid={r['id']:r for r in index}
for cell in range(72):
    for r in json.loads(gzip.decompress((OUT/'cells'/f'{cell:02d}'/'accepted.json.gz').read_bytes())):
        if r['id'] not in byid:continue
        hit=next(e for e in r['events'] if e['kind']=='ballBall' and set(e['balls'])=={'cueBall','object'})
        later=[e for e in r['events'] if e['time']>hit['time'] and e['kind']=='cushion' and e.get('ball') in ['cueBall','object']]
        byid[r['id']]['postContactMainRail']=any(0<=e.get('rail',-1)<6 for e in later)
        byid[r['id']]['postContactRail']=bool(later)
a['referencesWithoutPostContactMainRail']=sum(not r['postContactMainRail'] for r in index)
a['referencesWithoutPostContactRail']=sum(not r['postContactRail'] for r in index)
a['noLaterRailExample']=next(r['id'] for r in index if not r['postContactRail'] and r['n']==1)
a['successExample']=next(r['id'] for r in index if r['postContactRail'])
a['playerDiagnostic']='After target contact, either ball may contact any cushion, including pocket jaw; diagnostic only, no bank filtering.'
assert hashlib.sha256((ROOT/'QiuJi/Resources/kick-practice-bank.json').read_bytes()).hexdigest()==a['bankSHA256']
for name,value in [('audit.json',a),('bank-index.json',index)]: (OUT/name).write_text(json.dumps(value,indent=2)+'\n')
# Update only the exact numeric diagnostic fixture and one no-rail example.
p=ROOT/'QiuJiTests/KickPracticeTests.swift';s=p.read_text()
import re
s,n=re.subn(r'XCTAssertEqual\(referencesWithoutPostContactRail, \d+\)',f'XCTAssertEqual(referencesWithoutPostContactRail, {a["referencesWithoutPostContactRail"]})',s);assert n==1
s,n=re.subn(r'let referenceWithoutLaterRail = "[^"]+"',f'let referenceWithoutLaterRail = "{a["noLaterRailExample"]}"',s);assert n==1
p.write_text(s)
p=OUT/'integration.json';r=json.loads(p.read_text());r['auditSHA256']=hashlib.sha256((OUT/'audit.json').read_bytes()).hexdigest();r['current']['QiuJiTests/KickPracticeTests.swift']=hashlib.sha256((ROOT/'QiuJiTests/KickPracticeTests.swift').read_bytes()).hexdigest();p.write_text(json.dumps(r,indent=2)+'\n')
print('NO LATER CUSHION',a['referencesWithoutPostContactRail'],'NO LATER MAIN RAIL',a['referencesWithoutPostContactMainRail'],a['noLaterRailExample'],flush=True)

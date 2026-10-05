from pathlib import Path
import json, hashlib, zipfile, math
from PIL import Image, ImageDraw
r=Path(__file__).resolve().parents[2];out=r/'output/cue-scratch-selection-20261005/topdown-r1'
m=json.loads((out/'manifest.json').read_text());old=json.loads((out.parent/'r15-case-label-border/manifest.json').read_text())
assert [c['id'] for c in m['cases']]==[c['id'] for c in old['cases']]
files=[];cards=[];sheet=Image.new('RGB',(1440,1280),(240,243,239))
for i,(c,o) in enumerate(zip(m['cases'],old['cases'])):
    for key in ('speed','cutDegrees'):
        assert abs(c[key]-o[key])<1e-5,(c['id'],key)
    assert max(abs(a-b) for a,b in zip(c['ghostXYZ'],o['ghostXYZ']))<1e-5
    assert c['cueVisible'] and c['guidesCount']>0
    assert len(c['cuePath'])>2 and len(c['objectPath'])>2
    assert c['events']==o['events']
    assert abs(math.dist(c['objectXYZ'],c['ghostXYZ'])-.05715)<.0001
    im=Image.open(out/f'{c["id"]}.png');assert im.size==(1440,1920)
    sheet.paste(im.resize((480,640)),((i%3)*480,(i//3)*640))
    p=out/f'{c["id"]}.png';files.append({'id':c['id'],'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
    cards.append(f'<a href="{c["id"]}.png"><img alt="球形{"一二三四五六"[i]}" src="{c["id"]}.png"></a>')
sheet.save(out/'overview.jpg',quality=95)
(out/'index.html').write_text('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>母球掉袋：不吃库 · 俯视图文</title><style>body{margin:28px;background:#edf0eb;color:#173d2b;font-family:system-ui}h1{font-size:26px}p{font-size:16px}main{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px}img{width:100%;display:block;border-radius:12px}a{color:inherit}@media(max-width:800px){main{grid-template-columns:1fr}}</style><h1>母球掉袋：不吃库</h1><p>六个球形 · 俯视图 · 三条线、假想球、球杆及击球参数。点击图片查看原图。</p><p><a href="V023-俯视图文-六张原图.zip">下载六张原图</a></p><main>'+''.join(cards)+'</main>')
with zipfile.ZipFile(out/'V023-俯视图文-六张原图.zip','w',zipfile.ZIP_DEFLATED) as z:
    for i,c in enumerate(m['cases']):z.write(out/f'{c["id"]}.png',f'{i+1:02d}-球形{"一二三四五六"[i]}-{c["id"]}.png')
with zipfile.ZipFile(out/'V023-俯视图文-六张原图.zip') as z:assert z.testzip() is None
(out/'verification.json').write_text(json.dumps({'caseCount':6,'size':[1440,1920],'productionEventsEqualToR15':True,'cutSpeedAndGhostEqualToR15':True,'cueVisibleAllSix':True,'ghostTangentAllSix':True,'zipIntegrityPass':True,'nativeTestLog':'stills.log','files':files},ensure_ascii=False,indent=2))
print('PASS: six PNGs, same physics/cut/speed/ghost as r15, cue visible, zip integrity; visual review pending.')

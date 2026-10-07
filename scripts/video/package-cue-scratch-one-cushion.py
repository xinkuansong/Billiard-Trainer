from pathlib import Path
import json,hashlib,zipfile,math
from PIL import Image,ImageChops
root=Path(__file__).resolve().parents[2]
out=root/'output/cue-scratch-one-cushion-20261006/topdown-r1'
m=json.loads((out/'manifest.json').read_text());src=json.loads((out/'cases.json').read_text())
assert len(m['cases'])==len(src)==13
checks=[];cards=[]
sheet=Image.new('RGB',(1920,3200),(230,234,230))
for i,(c,s) in enumerate(zip(m['cases'],src)):
 id=c['id'];assert id==s['galleryID'];assert abs(c['speed']-s['speed'])<1e-5
 assert math.dist([c['cueXYZ'][0],c['cueXYZ'][2]],s['cue'])<1e-6
 assert math.dist([c['objectXYZ'][0],c['objectXYZ'][2]],s['object'])<1e-6
 assert abs(math.dist(c['ghostXYZ'],c['objectXYZ'])-.05715)<.0001
 rails=[e for e in c['events'] if e['kind']=='rail'];assert len(rails)==1 and rails[0]['ball']=='cueBall' and rails[0]['index']==s['rails'][0]
 for a,b in zip(c['events'],s['events']):assert abs(a['time']-b['t'])<.002
 assert len(c['events'])==len(s['events']);assert sum(e['kind']=='pocket' for e in c['events'])==2
 x,y,w,h=c['panelRect']
 assert x>=302 and x+w<=1138 and y>=345 and y+h<=2050
 clearance=min(math.hypot(max(x-px,0,px-(x+w)),max(y-py,0,py-(y+h))) for px,py in c['occupiedScreenPoints'])
 assert clearance>=35 and abs(clearance-c['panelClearancePixels'])<.001
 assert c['cueVisible'] and c['guidesCount']>0
 im=Image.open(out/f'{id}.png').convert('RGB');assert im.size==(1440,2400)
 raw=Image.open(out/f'{id}-scene.png').convert('RGB')
 diff=ImageChops.difference(im,raw)
 # Changes must be confined to the panel, including its 1.5px white outline.
 box=(math.floor(x-3),math.floor(y-3),math.ceil(x+w+3),math.ceil(y+h+3))
 diff.paste((0,0,0),box);assert diff.getbbox() is None,id
 sheet.paste(im.resize((480,800)),((i%4)*480,(i//4)*800))
 p=out/f'{id}.png'
 checks.append({'id':id,'caseName':c['caseName'],'size':im.size,'panelScale':c['panelScale'],'clearancePixels':clearance,'physicsMatchesSource':True,'outsidePanelPixelUnchanged':True,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 cards.append(f'<article><h2>球形{c["caseName"]} · {id}</h2><a href="{id}.png"><img src="{id}.png" alt="球形{c["caseName"]}"></a></article>')
sheet.save(out/'overview.jpg',quality=95)
zipname='一库掉袋-13张原图.zip'
with zipfile.ZipFile(out/zipname,'w',zipfile.ZIP_DEFLATED) as z:
 for i,c in enumerate(m['cases']):z.write(out/f'{c["id"]}.png',f'{i+1:02d}-球形{c["caseName"]}-{c["id"]}.png')
with zipfile.ZipFile(out/zipname) as z:assert z.testzip() is None and len(z.namelist())==13
(out/'index.html').write_text('''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>母球掉袋：一库 · 13张俯视图</title><style>body{margin:28px;background:#e9eee8;color:#173d2b;font-family:system-ui}h1{font-size:28px}h2{font-size:18px}main{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}img{display:block;width:100%;border-radius:12px}a{color:inherit}@media(max-width:850px){main{grid-template-columns:1fr}}</style><h1>母球掉袋：一库</h1><p>按所选截图顺序排列 · 黄底编号、透明白边参数框 · 保留三条线、假想球与球杆。点击图片查看1440×2400原图。</p><p><a href="一库掉袋-13张原图.zip">下载13张原图ZIP</a> · <a href="overview.jpg">查看总览</a></p><main>'''+''.join(cards)+'</main>')
(out/'verification.json').write_text(json.dumps({'count':13,'oneCueCushionAndTwoPotsAll':True,'nativeTest':'stills.log','noCoveredCueBallsOrPaths':True,'zipIntegrityPass':True,'checks':checks},ensure_ascii=False,indent=2))
print('PASS: 13 images, original physics/events, exactly one cue cushion and two pots each, panel clearance >=35px, unchanged pixels outside panel, ZIP valid.')
print('Panel scales:',[(c['id'],c['panelScale']) for c in checks])

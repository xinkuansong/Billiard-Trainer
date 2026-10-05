from pathlib import Path
import json,zipfile,hashlib
from PIL import Image,ImageChops,ImageDraw
from urllib.parse import quote
r=Path(__file__).resolve().parents[2];d=r/'output/cue-scratch-selection-20261005/padding-comparison-adaptive-panel';records=json.loads((d/'variants.json').read_text());assert len(records)==28
checks=[]
for c in records:
 a=Image.open(c['source']).convert('RGB');b=Image.open(c['path']).convert('RGB');x,y,w,h=c['originalRect']
 assert b.size==(c['width'],c['height'])
 diff=ImageChops.difference(a,b.crop((x,y,x+w,y+h)));assert diff.getbbox() is None,(c['id'],c['percent'])
 checks.append({'id':c['id'],'percent':c['percent'],'centerPixelIdentical':True,'dimensions':b.size,'paddingPixels':[x,y],'sha256':hashlib.sha256(Path(c['path']).read_bytes()).hexdigest()})
sheet=Image.new('RGB',(1440,1460),(230,234,231));draw=ImageDraw.Draw(sheet)
for col,percent in enumerate([5,10,15,20]):
 draw.text((col*360+20,12),f'{percent}% / each side',fill='black')
 for row,id in enumerate(['cover','M067']):
  c=next(c for c in records if c['percent']==percent and c['id']==id)
  im=Image.open(c['path']).convert('RGB');im.thumbnail((348,690))
  sheet.paste(im,(col*360+(360-im.width)//2,45+row*705))
sheet.save(d/'comparison.jpg',quality=95)
sections=[]
for percent in [5,10,15,20]:
 folder=d/f'{percent:02d}-percent';rs=[c for c in records if c['percent']==percent]
 with zipfile.ZipFile(d/f'留边{percent:02d}-封面及六图.zip','w',zipfile.ZIP_DEFLATED) as z:
  for c in rs:z.write(c['path'],Path(c['path']).name)
 images=''.join(f'<a href="{quote(str(Path(c["path"]).relative_to(d)))}"><img src="{quote(str(Path(c["path"]).relative_to(d)))}"></a>' for c in rs)
 sections.append(f'<section><h2>四周各留 {percent}%</h2><p><a href="{quote(f"留边{percent:02d}-封面及六图.zip")}">下载本档7张原图</a></p><main>{images}</main></section>')
with zipfile.ZipFile(d/'四档留边-28张原图.zip','w',zipfile.ZIP_DEFLATED) as z:
 for c in records:z.write(c['path'],str(Path(c['path']).relative_to(d)))
for p in d.glob('*.zip'):
 with zipfile.ZipFile(p) as z:assert z.testzip() is None
(d/'index.html').write_text('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>四档安全留边对比</title><style>body{margin:28px;background:#e9ede8;color:#14382a;font-family:system-ui}main{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}img{width:100%}a{color:inherit}section{margin-top:40px}@media(max-width:800px){main{grid-template-columns:repeat(2,1fr)}}.summary{max-width:1200px;width:100%}</style><h1>自适应竖框版 · 四档留边对比</h1><p>每侧5%、10%、15%、20%四档；六张球形图采用黄底标题、透明竖框，自动避让球、球杆与三线；独立封面沿用上一版；加大字号，中央原图像素完全保留，只扩展外围地面。请上传平台比较裁切。</p><p><a href="'+quote('四档留边-28张原图.zip')+'">下载全部28张</a></p><img class="summary" src="comparison.jpg">'+''.join(sections))
(d/'verification.json').write_text(json.dumps({'images':28,'allOriginalCentersPixelIdentical':True,'allZipIntegrityPass':True,'checks':checks},ensure_ascii=False,indent=2))
print('PASS: 28 central image regions pixel-identical; 5 ZIP archives valid.')

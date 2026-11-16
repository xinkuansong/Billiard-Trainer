from pathlib import Path
import json, shutil, sys
from PIL import Image, ImageDraw, ImageFont
source=Path(sys.argv[1]); out=Path(sys.argv[2]); out.mkdir(parents=True,exist_ok=True)
manifest=json.loads((source/'manifest.json').read_text())
items=[a for t in manifest for a in t['attachments']]
files={}
for a in items:
    label=a['suggestedHumanReadableName']
    if label.startswith('brightness-'):
        stem=label.split('_0_')[0]
        ext=Path(a['exportedFileName']).suffix
        shutil.copy2(source/a['exportedFileName'],out/(stem+ext));files[stem]=out/(stem+ext)
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',32)
small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',22)
for view in ['overview','close','top']:
    canvas=Image.new('RGB',(2448,566),'#111820');d=ImageDraw.Draw(canvas)
    for i,(variant,label) in enumerate([('A-original','A  ORIGINAL'),('B-light','B  LIGHT'),('C-bright','C  BRIGHT')]):
        path=files[f'brightness-{view}-{variant}']
        im=Image.open(path).convert('RGB');assert im.size==(1600,1000)
        d.text((16+i*816,11),label,font=font,fill='white')
        canvas.paste(im.resize((800,500),Image.Resampling.LANCZOS),(16+i*816,58))
    canvas.save(out/(view+'-comparison.jpg'),quality=95,subsampling=0)
(out/'package.json').write_text(json.dumps({'source':str(source),'files':{k:str(v) for k,v in files.items()},'note':'Original rendered PNGs unchanged; comparison strips only resized and labeled.'},ensure_ascii=False,indent=2))
assert len([k for k in files if k!='brightness-preview'])==9
# Same pixel crop for all variants: reveal ball finishes without repainting.
box=(440,310,1180,745)
canvas=Image.new('RGB',(2280,501),'#111820');d=ImageDraw.Draw(canvas)
for i,(variant,label) in enumerate([('A-original','A  ORIGINAL'),('B-light','B  LIGHT'),('C-bright','C  BRIGHT')]):
    im=Image.open(files[f'brightness-close-{variant}']).convert('RGB').crop(box)
    d.text((10+i*760,11),label,font=font,fill='white')
    canvas.paste(im,(10+i*760,58))
canvas.save(out/'ball-detail-comparison.jpg',quality=95,subsampling=0)

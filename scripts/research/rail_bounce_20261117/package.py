from pathlib import Path
import json, shutil, sys
from PIL import Image, ImageDraw, ImageFont
source=Path(sys.argv[1]); out=Path(sys.argv[2]); out.mkdir(parents=True,exist_ok=True)
manifest=json.loads((source/'manifest.json').read_text())
files={}
for test in manifest:
    for a in test['attachments']:
        label=a['suggestedHumanReadableName']
        if label.startswith('rail-bounce-'):
            stem=label.split('_0_')[0]
            ext=Path(a['exportedFileName']).suffix
            shutil.copy2(source/a['exportedFileName'],out/(stem+ext)); files[stem]=out/(stem+ext)
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',26)
for view in ['low','oblique','top']:
    canvas=Image.new('RGB',(1624,550),'#111820'); d=ImageDraw.Draw(canvas)
    for i,(variant,label) in enumerate([('A-original','BEFORE'),('B-bounce','AFTER  CLOTH BOUNCE')]):
        im=Image.open(files[f'rail-bounce-{view}-{variant}']).convert('RGB')
        assert im.size==(1600,1000)
        canvas.paste(im.resize((800,500),Image.Resampling.LANCZOS),(8+i*808,45))
        d.text((12+i*808,8),label,font=font,fill='white')
    canvas.save(out/(view+'-comparison.jpg'),quality=96,subsampling=0)
(out/'package.json').write_text(json.dumps({'source':str(source),'files':{k:str(v) for k,v in files.items()},'note':'Native original PNGs retained. Comparison only resized and labeled.'},indent=2))

from pathlib import Path
import json, shutil, sys
from PIL import Image, ImageDraw, ImageFont
source=Path(sys.argv[1]); out=Path(sys.argv[2]); out.mkdir(parents=True,exist_ok=True)
manifest=json.loads((source/'manifest.json').read_text()); files={}
for test in manifest:
    for a in test['attachments']:
        label=a['suggestedHumanReadableName']
        if label.startswith('rail-shape-'):
            stem=label.split('_0_')[0]; ext=Path(a['exportedFileName']).suffix
            shutil.copy2(source/a['exportedFileName'],out/(stem+ext));files[stem]=out/(stem+ext)
font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',25)
variants=[('A-original','原版'),('B-bounce','上一版：仅反弹光'),('C-soft','本轮：柔化'),('D-softPlus','本轮：更柔和')]
for view in ['low','oblique','top']:
    canvas=Image.new('RGB',(1624,1100),'#111820');d=ImageDraw.Draw(canvas)
    for i,(variant,label) in enumerate(variants):
        im=Image.open(files[f'rail-shape-{view}-{variant}']).convert('RGB');assert im.size==(1600,1000)
        x=8+(i%2)*808;y=(i//2)*550
        canvas.paste(im.resize((800,500),Image.Resampling.LANCZOS),(x,y+45));d.text((x+4,y+8),label,font=font,fill='white')
    canvas.save(out/(view+'-comparison.jpg'),quality=96,subsampling=0)
# Same native pixels/crop in all rows; no recolouring or generated content.
for name,chosen in [('four-way-detail',variants),('before-after-detail',[variants[0],variants[3]]),('iteration-detail',[variants[1],variants[3]])]:
    box=(640,370,1600,550);w=box[2]-box[0];h=box[3]-box[1]
    canvas=Image.new('RGB',(w+24,len(chosen)*(h+50)),'#111820');d=ImageDraw.Draw(canvas)
    for i,(variant,label) in enumerate(chosen):
        im=Image.open(files[f'rail-shape-oblique-{variant}']).convert('RGB').crop(box)
        y=i*(h+50);d.text((12,y+3),label,font=font,fill='white');canvas.paste(im,(12,y+42))
    canvas.save(out/(name+'.png'))
(out/'package.json').write_text(json.dumps({'source':str(source),'files':{k:str(v) for k,v in files.items()},'note':'Native original PNGs retained. Comparison only cropped/resized and labelled.'},ensure_ascii=False,indent=2))

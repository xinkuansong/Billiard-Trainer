from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,shutil,sys
source=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
files={}
for test in json.loads((source/'manifest.json').read_text()):
 for a in test['attachments']:
  label=a['suggestedHumanReadableName']
  if label.startswith('rail-shadow-lift-'):
   stem=label.split('_0_')[0];path=out/(stem+Path(a['exportedFileName']).suffix)
   shutil.copy2(source/a['exportedFileName'],path);files[stem]=str(path)
font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',25)
variants=[('A-original','最初原版'),('B-finesse','上一版：原版细化'),('C-shadowLift','本轮：暗部轻提')]
for view in ['low','oblique','detail','top']:
 canvas=Image.new('RGB',(2432,550),'#111820');d=ImageDraw.Draw(canvas)
 for i,(v,label) in enumerate(variants):
  im=Image.open(files[f'rail-shadow-lift-{view}-{v}']).convert('RGB');assert im.size==(1600,1000)
  canvas.paste(im.resize((800,500),Image.Resampling.LANCZOS),(8+i*808,45));d.text((12+i*808,8),label,font=font,fill='white')
 canvas.save(out/(view+'-comparison.jpg'),quality=96,subsampling=0)
for view,box in [('oblique',(640,370,1600,550)),('detail',(200,400,1400,630))]:
 w=box[2]-box[0];h=box[3]-box[1]
 canvas=Image.new('RGB',(w+24,2*(h+50)),'#111820');d=ImageDraw.Draw(canvas)
 for i,(v,label) in enumerate([variants[1],variants[2]]):
  im=Image.open(files[f'rail-shadow-lift-{view}-{v}']).convert('RGB').crop(box)
  y=i*(h+50);d.text((12,y+3),label,font=font,fill='white');canvas.paste(im,(12,y+42))
 canvas.save(out/(view+'-before-after.png'))
(out/'package.json').write_text(json.dumps({'source':str(source),'files':files,'note':'Native source images; crops/resizing/labels only.'},ensure_ascii=False,indent=2))

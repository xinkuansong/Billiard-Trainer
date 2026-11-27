from pathlib import Path
import json,sys,subprocess
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageDraw,ImageFont
out=Path(sys.argv[1]);samples=json.loads((out/'samples.json').read_text());primary={r['sampleID']:r['reference'] for r in json.loads((out/'primary.json').read_text())}
def render(q):
 p=out/f"{q['sampleID']}.svg";subprocess.run(['/opt/homebrew/bin/rsvg-convert',str(p),'-o',str(p.with_suffix('.png'))],check=True)
with ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(render,samples))
font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',16)
for kind in ['one','two_black','two_own','three']:
 sheet=Image.new('RGB',(1500,2560),'#f3f4ee');draw=ImageDraw.Draw(sheet)
 for i,q in enumerate(q for q in samples if q['kind']==kind):
  x=i%5*300;y=i//5*640;r=primary[q['sampleID']]
  im=Image.open(out/f"{q['sampleID']}.png").convert('RGBA');sheet.paste(im,(x,y+25),im)
  draw.text((x+12,y+4),q['sampleID'],font=font,fill='#274f42')
  if r:
   text='全挡' if r['metrics']['fullBlock'] else '未全挡'
   if r['cornerWitnesses']:text+=' / 选袋待核'
   draw.text((x+12,y+583),f"{text}  容错 {r['cueWidth']:.5f}°",font=font,fill='#aa6630')
   draw.text((x+12,y+610),f"舒适 {r['comfort']:.2f}  距离 {r['metrics']['distance']:.2f}m",font=font,fill='#345d49')
  else:draw.text((x+12,y+583),'本轮可出杆限制下未找到',font=font,fill='#aa6630')
 sheet.save(out/f'contact-{kind}.png')
print('Rendered 80 diagrams / 4 five-column contact sheets')

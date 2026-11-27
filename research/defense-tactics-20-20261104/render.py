from pathlib import Path
import json,subprocess,sys
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'output/defense-tactics-20-20261104/r3'
samples=json.loads((OUT/'samples.json').read_text())
primary={x['sampleID']:x['reference'] for x in json.loads((OUT/'primary.json').read_text())}
def render(q):
 p=OUT/f"{q['sampleID']}.svg"
 subprocess.run(['/opt/homebrew/bin/rsvg-convert',str(p),'-o',str(p.with_suffix('.png'))],check=True)
with ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(render,samples))
font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',15)
sheet=Image.new('RGB',(1500,2640),'#f3f4ee');draw=ImageDraw.Draw(sheet)
for i,q in enumerate(samples):
 x=i%5*300;y=i//5*660;r=primary[q['sampleID']]
 im=Image.open(OUT/f"{q['sampleID']}.png").convert('RGBA');sheet.paste(im,(x,y+30),im)
 draw.text((x+10,y+6),q['sampleID']+f"  我方{q['numbers'][q['own']]} / 对方{q['numbers'][q['enemy']]}",font=font,fill='#274f42')
 if r:
  status='直击全挡' if r['metrics']['fullBlock'] else '小容错 + 低舒适'
  draw.text((x+10,y+588),status,font=font,fill='#aa6630')
  draw.text((x+10,y+612),f"容错{r['cueWidth']:.6f}° / 舒适{r['comfort']:.2f}",font=font,fill='#345d49')
  n=sum(p.get('qualifies',False) for p in r['perturbations'])
  draw.text((x+10,y+636),f'小扰动仍过门槛 {n}/4',font=font,fill='#345d49')
 else:draw.text((x+10,y+592),'本轮未找到过门槛的参考解',font=font,fill='#aa6630')
sheet.save(OUT/'contact-all.png')
for i,k in enumerate(['one','two_black','two_own','three']):sheet.crop((0,i*660,1500,(i+1)*660)).save(OUT/f'contact-{k}.png')
print('Rendered 20 SVG/PNG diagrams, 4 category strips, 1 overview')

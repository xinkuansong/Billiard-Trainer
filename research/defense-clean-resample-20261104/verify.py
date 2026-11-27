from pathlib import Path
import ast,hashlib,json,gzip,random,subprocess,xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/defense-clean-resample-20261104'
BASE=ROOT/'output/defense-pocket-cleanup-20261104'
read=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=Path(__file__).with_name('build.py')
node=next(n for n in ast.parse(source.read_text()).body if isinstance(n,ast.FunctionDef) and n.name=='layout_key')
exec(compile(ast.Module(body=[node],type_ignores=[]),str(source),'exec'))
samples=read(OUT/'samples.json');manifest=read(OUT/'sampling.json');page=(OUT/'review.html').read_text()
old=[q for item in manifest['previousSamples'] for q in read(ROOT/item['path'])]
ids={q['formationID'] for q in old};layouts={layout_key(q) for q in old}
assert len(samples)==80
assert not any(q['formationID'] in ids or layout_key(q) in layouts for q in samples)
assert page.count('<article class="card"')==80 and page.count('<div class="grid">')==4
assert page.count('class="vote"')==80 and 'grid-template-columns:repeat(5,minmax(265px,1fr))' in page
assert 'src="http' not in page and 'href="http' not in page
removed={d['key'] for d in read(BASE/'decisions.json') if d['remove']}
for kind,m in manifest['catalogs'].items():
    path=BASE/'catalogs'/f'{kind}.jsonl.gz';assert sha(path)==m['catalogSHA256']
    with gzip.open(path,'rt') as f:pool=[json.loads(line) for line in f]
    eligible=[q for q in pool if q['formationID'] not in ids and layout_key(q) not in layouts]
    selected=[q for q in samples if q['kind']==kind]
    assert len(selected)==20 and len({q['formationID'] for q in selected})==20
    expected=random.Random(m['seed']).sample(eligible,20)
    assert [{k:v for k,v in q.items() if k!='sampleID'} for q in selected]==expected
    for q in selected:
        assert f"{q['bank']}|{q['sourceID']}|{q['own']}" not in removed
        assert 1e-6<q['ownAttack']['best']['cueWidth']<=.008 and q['maxPocketComfort']<10
        svg=(OUT/f"{q['sampleID']}.svg").read_text();root=ET.fromstring(svg)
        assert root.attrib['viewBox']=='0 0 300 552'
        labels=[e.text for e in root.iter('{http://www.w3.org/2000/svg}text')]
        assert labels[6:]==list(map(str,q['numbers'])) and svg in page

def render(q):
    subprocess.run(['/opt/homebrew/bin/rsvg-convert',str(OUT/f"{q['sampleID']}.svg"),'-o',str(OUT/f"{q['sampleID']}.png")],check=True)
with ThreadPoolExecutor(max_workers=4) as ex:list(ex.map(render,samples))
font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',18)
for kind in manifest['catalogs']:
    sheet=Image.new('RGB',(1500,2560),'#f3f4ee');draw=ImageDraw.Draw(sheet)
    for i,q in enumerate(q for q in samples if q['kind']==kind):
        x=(i%5)*300;y=(i//5)*640
        sheet.paste(Image.open(OUT/f"{q['sampleID']}.png").convert('RGB'),(x,y+25))
        draw.text((x+15,y+5),q['sampleID'],fill='#274f42',font=font)
        draw.text((x+15,y+582),f"容错 {q['ownAttack']['best']['cueWidth']:.6f}°",fill='#aa6630',font=font)
        draw.text((x+15,y+607),f"舒适 {q['maxPocketComfort']:.2f}",fill='#345d49',font=font)
    sheet.save(OUT/f'contact-{kind}.png')
report=dict(passed=True,count=80,perClass=20,columns=5,previousFormationOverlap=0,previousMirroredLayoutOverlap=0,sourceRecordsExact=True,seedsReproduced=True,cleanupRemovedOverlap=0,svgAndPngCount=80,htmlSHA256=sha(OUT/'review.html'),scope='Offline data/SVG checks and rendered diagram sheets; not a browser screenshot or defense solution validation')
(OUT/'audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))

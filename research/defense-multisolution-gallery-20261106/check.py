from pathlib import Path
import json,re,xml.etree.ElementTree as ET,math,subprocess
from html.parser import HTMLParser
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-multisolution-gallery-20261106'
m=json.loads((OUT/'manifest.json').read_text());snap=json.loads((OUT/'snapshot.json').read_text())
ns={'s':'http://www.w3.org/2000/svg'};links=0;routes=0
class Links(HTMLParser):
 def handle_starttag(self,tag,attrs):
  global links
  for k,v in attrs:
   if k in ['href','src'] and v and not v.startswith(('#','https:','http:')):
    assert (self.file.parent/v).exists(),(self.file,v);links+=1
for f in OUT.rglob('*.html'):
 p=Links();p.file=f;p.feed(f.read_text())
for f in sorted((OUT/'cases').glob('*/routes.json')):
 data=json.loads(f.read_text());q=data['question'];result=data['result']
 for r in result['routes']:
  routes+=1;file=f.parent/f'route-{r["id"]:02}.svg';svg=ET.parse(file)
  lines=svg.findall('.//s:polyline',ns);assert len(lines)==6
  assert 'stroke-dasharray' not in lines[0].attrib and 'stroke-dasharray' not in lines[1].attrib
  assert all(l.attrib.get('stroke-dasharray')=='7 5' for l in lines[2:])
  assert lines[1].attrib['stroke']=='#ffffff' and lines[3].attrib['stroke']=='#ffffff'
  assert lines[5].attrib['stroke']==('#18211f' if q['ownBallNumber']==8 else '#f5c226')
  def end(line):
   x,y=map(float,line.attrib['points'].split()[-1].split(','));return [x/300-1.47,y/300-.83]
  assert math.dist(end(lines[3]),r['finalPositions']['cueBall'])<1e-7
  assert math.dist(end(lines[5]),r['finalPositions']['_'+str(q['ownBallNumber'])])<1e-7
  assert r['probePasses']==4 and r['replayVerified']
assert routes==m['routes']==len(list((OUT/'cases').glob('*/*.svg')))
assert m['multi']+m['single']==m['layouts']==len(snap['records'])
# Execute the actual directory filtering script in Node with a minimal DOM, every option + search.
index=(OUT/'index.html').read_text();script=re.search(r'<script>(.*?)</script>',index,re.S)[1]
attrs=re.findall(r'data-kind="([^"]+)" data-n="([^"]+)" data-search="([^"]+)"',index)
node="const vm=require('vm');const cards="+json.dumps([{'dataset':dict(kind=k,n=n,search=s)} for k,n,s in attrs])+";let filter={value:'multi',addEventListener(){}},search={value:'',addEventListener(){}},count={};let context={document:{getElementById:(id)=>({filter,search,count}[id]),querySelectorAll:()=>cards}};vm.createContext(context);vm.runInContext("+json.dumps(script)+",context);let out={};for(const f of ['multi','all','single','two_black','two_own','three']){filter.value=f;vm.runInContext('update()',context);out[f]=cards.filter(c=>!c.hidden).length;}filter.value='all';search.value='G0001';vm.runInContext('update()',context);out.search=cards.filter(c=>!c.hidden).length;console.log(JSON.stringify(out));"
counts=json.loads(subprocess.check_output(['node','-e',node],text=True));assert counts['multi']==m['multi'] and counts['all']==m['layouts'] and counts['single']==m['single'] and counts['search']==1
for k in m['kinds']:assert counts[k]==m['kinds'][k]
report=dict(passed=True,layouts=m['layouts'],routes=routes,linksChecked=links,filters=counts,geometryChecks=m['geometrySourceChecks'],visualReview=['preview-01.png','preview-09.png','preview-11.png'],scope='Structural and coordinate audits, real filter script in Node, PNG visual review. Not native App UI or browser interaction acceptance.')
(OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False))

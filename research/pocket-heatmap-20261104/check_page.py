from pathlib import Path
import re,json,hashlib,subprocess,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/pocket-heatmap-20261104/r2';HERE=Path(__file__).parent
h=(OUT/'review.html').read_text();script=re.search(r'<script>(.*?)</script>',h,re.S).group(1)
assert not re.search(r'(?:src|href)="https?://',h)
manifest=json.loads((OUT/'render-manifest.json').read_text());sha=lambda b:hashlib.sha256(b).hexdigest()
for name,digest in manifest['files'].items():assert sha((OUT/name).read_bytes())==digest
assert manifest['gridSHA256']==sha((OUT/'grid.json').read_bytes())==json.loads((OUT/'audit.json').read_text())['gridSHA256']
assert script.endswith((HERE/'inspector.js').read_text())
ET.fromstring((OUT/'heatmap.svg').read_text())
# Execute the actual embedded consumer, not a second port of its selection logic.
stub='''const assert=require('node:assert/strict');let rects=0;const ctx=new Proxy({},{get(t,k){if(k==='fillRect')return()=>rects++;return()=>{}},set(){return true}});function canvas(){return {getContext(){return ctx},getBoundingClientRect(){return {left:0,top:0,width:450,height:840}},addEventListener(k,fn){this.click=fn}}};const elements={heat:canvas(),region:canvas(),detail:{},ranking:{}};const document={getElementById(id){return elements[id]}};
'''
test='''
for (const c of DATA.cells) {assert.strictEqual(nearest(DATA.x[c.ix],DATA.z[c.iz]),c);if(c.valid){const rank=ranking(c);assert.equal(rank.length,6);assert.equal(rank[0].width,c.maxDegrees);if(c.maxDegrees>0)assert.equal(rank[0].pocket,c.bestPocket)}}
let clicks=0;for(const ix of [0,25,50,75,100])for(const iz of [0,25,50]){const c=cellAt(ix,iz),[u,v]=xy(DATA.x[ix],DATA.z[iz]);for(const cv of [elements.heat,elements.region]){cv.click({clientX:u,clientY:v});assert.equal(elements.detail.textContent,description(c));assert.equal((elements.ranking.innerHTML.match(/<tr>/g)||[]).length,6);clicks++}}
console.log(JSON.stringify({cells:DATA.cells.length,clicks,drawCalls:rects}));
'''
r=subprocess.run(['node','-'],input=stub+script+test,text=True,capture_output=True);assert r.returncode==0,r.stderr
report={'passed':True,'checks':json.loads(r.stdout),'htmlSHA256':sha(h.encode()),'scope':'all-cell nearest-grid/ranking checks and 30 actual-handler clicks with mocked canvas/DOM, hash/XML checks; not live browser rendering or accessibility acceptance'}
(OUT/'page-check.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

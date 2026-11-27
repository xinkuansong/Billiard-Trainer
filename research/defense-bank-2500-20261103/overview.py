"""Single-file, five-column overview of all audited questions; raw data unchanged."""
from pathlib import Path
import ast,base64,collections,hashlib,html,json,math,os,re
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/defense-bank-2500-20261103/review'
# Reuse the exact scientific drawing helpers from the inspected 15-figure gallery.
ns={'__file__':str(HERE/'deliver.py')};os.environ['DEFENSE_PILOT_OUTPUT']=str(OUT)
exec((HERE/'deliver.py').read_text().split('light=[];bank=[];rows=[]')[0],ns)
text,panel,zoom,opening_label=(ns[k] for k in ['text','panel','zoom','opening_label'])
index=ns['index'];audit=ns['audit'];checks=ns['checks'];NAMES=ns['NAMES'];ZONES=ns['ZONES']
assert len(index)==2500

def figure(q):
 svg='<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="870"><rect width="1200" height="870" fill="#f5f7f2"/>'
 svg+=text(32,39,f"{q['id']} · {NAMES[q['family']]}",27,weight=650)
 svg+=text(32,70,f"{ZONES[q['zone']]} · 开局进攻舒适度 {opening_label(q['openingComfort'])}/100 · 先合法碰{q['ownKey'][1:]}号",17)
 for i,(title,body) in enumerate([('开局 · 先想怎样做遮挡',panel(q)),('参考打法 · 实际模拟轨迹',panel(q,q['reference'])),('停稳遮挡检查 · 局部放大',zoom(q))]):
  svg+=f'<g transform="translate({400*i},90)">'+text(190,12,title,19,weight=600,anchor='middle')+body+'</g>'
 shot=q['reference']['shot'];spin='中杆' if shot['spinY']==0 else '高杆' if shot['spinY']>0 else '低杆'
 svg+=text(32,773,f"{spin} · 杆速 {shot['speed']:.2f} m/s · 无侧塞",18,weight=550)+text(610,773,'完整遮挡100 · 8次小幅微调仍挡住',20,weight=650)
 svg+=text(32,814,'浅蓝：母球轨迹 · 黄色：我方球轨迹 · 虚圈：起点 · 实心球：停点',16)
 s=checks[q['id']]['stress'];svg+=text(32,844,f"较大微调挡住：中档{s['medium'].get('full',0)}/8；宽档{s['wide'].get('full',0)}/8。有限探针不代表实台成功率。",16)+'</svg>'
 return svg

HEAD='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>防守题库 · 全部2500题 · 每行5张</title><style>
*{box-sizing:border-box}html{scroll-padding-top:145px}body{margin:0;background:#edf1eb;color:#193731;font:15px/1.6 "PingFang SC",system-ui,sans-serif}header{position:sticky;top:0;z-index:2;background:#f7faf5f5;border-bottom:1px solid #cbd8cd;padding:12px 24px;backdrop-filter:blur(10px)}h1{font-size:23px;margin:0}p{margin:4px 0}.muted{color:#63756b}nav{display:flex;gap:10px;flex-wrap:wrap;margin-top:8px}nav a,button{font:inherit;color:inherit}nav a{padding:4px 12px;border:1px solid #b3c7b9;border-radius:8px;text-decoration:none;background:white}nav a:hover{background:#e1eee4}main{padding:12px 20px 40px;min-width:1200px}.family{scroll-margin-top:145px;margin-bottom:28px}.family h2{font-size:20px;margin:12px 0}.family h2 span{font-size:14px;font-weight:400;color:#63756b;margin-left:15px}.grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:12px}.tile{display:block;width:100%;min-width:0;border:1px solid #cfdbd0;border-radius:10px;background:#fff;padding:7px;cursor:zoom-in;text-align:left;content-visibility:auto;contain-intrinsic-size:auto 225px}.tile:hover{border-color:#26765a;box-shadow:0 3px 12px #173b2820}.tile:focus-visible,a:focus-visible{outline:3px solid #217d5d;outline-offset:2px}.tile img{display:block;width:100%;height:auto;aspect-ratio:1200/870}.caption{display:flex;justify-content:space-between;gap:4px;padding:5px 4px 0;font-size:12px;white-space:nowrap}.caption b{font-weight:600}.caption span{color:#63756b}dialog{border:0;border-radius:14px;padding:12px;background:#f5f7f2;max-width:calc(100vw -24px);max-height:calc(100vh -24px)}dialog::backdrop{background:#0b1f18c9}.viewerbar{display:flex;align-items:center;gap:12px;justify-content:space-between;margin-bottom:8px}.viewerbar button{min-height:40px;border:1px solid #afc5b5;border-radius:8px;background:white;padding:6px 16px;cursor:pointer}.viewerbar button:disabled{opacity:.35;cursor:default}#large{display:block;width:min(1440px,calc(100vw -60px));height:auto;max-height:calc(100vh -105px);object-fit:contain}#viewerTitle{font-weight:600}footer{padding:0 24px 25px;color:#63756b}@media print{header{position:static}nav,dialog{display:none}main{min-width:0}.tile{content-visibility:visible;break-inside:avoid;padding:0}.grid{gap:5px}.caption{font-size:8px}.family{break-before:page}}
</style></head><body><header id="top"><h1>纯防守题库 · 全部2500题</h1><p class="muted">五类各500题，每行5张。点击图片放大；放大后可用 ← → 切题，Esc关闭。小窗口可横向滚动查看五列。</p><nav aria-label="题型导航">'''
SCRIPT='''const tiles=Array.from(document.querySelectorAll('.tile')),viewer=document.getElementById('viewer'),large=document.getElementById('large'),title=document.getElementById('viewerTitle'),previous=document.getElementById('previous'),next=document.getElementById('next');let selected=0,origin=null;
function show(index){selected=index;const tile=tiles[index],img=tile.querySelector('img');large.src=img.src;large.alt=img.alt;title.textContent=tile.dataset.id+' · '+(index+1)+' / '+tiles.length;previous.disabled=index===0;next.disabled=index===tiles.length-1;}
for(const [index,tile] of tiles.entries())tile.addEventListener('click',()=>{origin=tile;show(index);viewer.showModal();});
previous.addEventListener('click',()=>{if(selected>0)show(selected-1);});next.addEventListener('click',()=>{if(selected<tiles.length-1)show(selected+1);});document.getElementById('close').addEventListener('click',()=>viewer.close());
viewer.addEventListener('click',event=>{if(event.target===viewer){const r=viewer.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)viewer.close();}});
viewer.addEventListener('keydown',event=>{if(event.key==='ArrowLeft'&&selected>0){event.preventDefault();show(selected-1);}else if(event.key==='ArrowRight'&&selected<tiles.length-1){event.preventDefault();show(selected+1);}});
viewer.addEventListener('close',()=>{large.removeAttribute('src');if(origin)origin.focus({preventScroll:true});});'''
report=[];number=0
with (OUT/'all-2500-five-columns.html').open('w') as f:
 f.write(HEAD)
 for family,name in NAMES.items():f.write(f'<a href="#{family}">{html.escape(name)}</a>')
 f.write('</nav></header><main>')
 for family,name in NAMES.items():
  entries=[e for e in index if e['family']==family];assert len(entries)==500
  f.write(f'<section class="family" id="{family}"><h2>{html.escape(name)}<span>500题 · 长库250 / 短库150 / 离库100</span></h2><div class="grid">')
  for e in entries:
   raw=(OUT/e['file']).read_bytes();assert hashlib.sha256(raw).hexdigest()==audit['sourceHashes'][e['file']]
   q=json.loads(raw);svg=figure(q);assert not re.search(r'\b(?:NaN|Infinity|undefined)\b',svg)
   old=OUT/'figures'/f"{q['id']}.svg"
   if old.exists():assert old.read_text()==svg,q['id']
   encoded=base64.b64encode(svg.encode()).decode();alt=f"{q['id']}，{name}，{ZONES[q['zone']]}，开局、参考轨迹和停稳遮挡放大图"
   loading='eager' if number<5 else 'lazy'
   f.write(f'<button type="button" class="tile" data-id="{q["id"]}" aria-label="放大 {html.escape(alt)}"><img width="1200" height="870" loading="{loading}" decoding="async" src="data:image/svg+xml;base64,{encoded}" alt="{html.escape(alt)}"><span class="caption"><b>{q["id"]}</b><span>{ZONES[q["zone"]]}</span></span></button>')
   report.append({'id':q['id'],'family':family,'svgSHA256':hashlib.sha256(svg.encode()).hexdigest()});number+=1
  f.write('</div></section>');print(f'{family}: 500 figures embedded',flush=True)
 f.write('</main><footer>每张从左到右：开局 → 实际模拟路线 → 停稳遮挡放大。完整遮挡100为防守结果，题目难度尚未定级。本图册为离线审阅资料。</footer><dialog id="viewer" aria-labelledby="viewerTitle"><div class="viewerbar"><span id="viewerTitle"></span><div><button id="previous" aria-label="上一题">← 上一题</button> <button id="next" aria-label="下一题">下一题 →</button> <button id="close">关闭 ✕</button></div></div><img id="large" alt=""></dialog><script>'+SCRIPT+'</script></body></html>')
path=OUT/'all-2500-five-columns.html'
(OUT/'overview-manifest.json').write_text(json.dumps({'questions':number,'columns':5,'rows':500,'singleFile':True,'bytes':path.stat().st_size,'htmlSHA256':hashlib.sha256(path.read_bytes()).hexdigest(),'existing15FiguresByteIdentical':True,'figures':report},ensure_ascii=False,indent=2))
print(f'DONE {number} figures, {path.stat().st_size/1e6:.1f} MB: {path}')

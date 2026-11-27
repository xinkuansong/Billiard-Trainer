#!/usr/bin/env python3
"""Local evidence viewer. Uses actual same-state frames, no interpolation."""
import html,json,os,re,sys
from pathlib import Path
from urllib.parse import quote
source=Path(sys.argv[1]).resolve();output=Path(os.environ['QIUJI_TEST_EVIDENCE']).resolve();files={}
for t in json.loads((source/'attachments/manifest.json').read_text()):
 for a in t['attachments']:
  if a['exportedFileName'].endswith('.png'):
   name=re.sub(r'_[0-9]+_[0-9A-Fa-f-]{36}\.png$','',a['suggestedHumanReadableName'])
   files[name]=quote(os.path.relpath(source/'attachments'/a['exportedFileName'],output))
groups={}
for pose,label in [('app-default','每日机位'),('near','近景'),('low','低机位'),('overview','俯视')]:
 groups[label]=[[files['b0-'+pose+'-current'],files['b0-'+pose+'-candidate']]]
for prefix,label,count in [('orbit-flat-balls','环绕／球在台面',72),('orbit-lifted-balls','环绕／抬高球',72)]+[(f'pocket-{i}',f'袋口 {i+1}',12) for i in range(6)]:
 groups[label]=[[files[f'{prefix}-{i}-A'],files[f'{prefix}-{i}-B']] for i in range(count)]
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>台呢静态结果对照</title>
<style>body{background:#171a1d;color:#f3f5f7;font:16px system-ui;margin:24px}h1{font-size:24px}p{color:#b9c0c7}button,select,input{font:inherit;padding:8px;margin:6px}main{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{width:100%;display:block}figcaption{padding:8px;text-align:center}a{color:inherit}#status{font-variant-numeric:tabular-nums}</style>
<h1>台呢静态结果：原版 / 候选</h1><p>左原版，右候选。全部来自相同场景状态；这是离屏测试序列，播放速度不代表 App 帧率。点图片可看原尺寸。</p>
<select id="group"></select><button id="play">播放序列</button><input id="frame" type="range" min="0" value="0"><span id="status"></span>
<main><figure><a id="linkA"><img id="a"></a><figcaption>原版</figcaption></figure><figure><a id="linkB"><img id="b"></a><figcaption>静态响应候选</figcaption></figure></main>
<script>const groups=DATA;const select=document.getElementById('group'),slider=document.getElementById('frame'),play=document.getElementById('play'),status=document.getElementById('status');let playing=false,request=0,timer;
for(const name of Object.keys(groups)){const o=document.createElement('option');o.textContent=name;select.append(o)}
async function show(){const id=++request,frames=groups[select.value],i=Number(slider.value);slider.max=frames.length-1;const urls=frames[Math.min(i,frames.length-1)];const pics=urls.map(src=>{const img=new Image();img.src=src;return img});await Promise.all(pics.map(img=>img.decode()));if(id!==request)return;document.getElementById('a').src=urls[0];document.getElementById('b').src=urls[1];document.getElementById('linkA').href=urls[0];document.getElementById('linkB').href=urls[1];status.textContent=`${Math.min(i,frames.length-1)+1} / ${frames.length}`;}
function stop(){playing=false;clearTimeout(timer);play.textContent='播放序列'}
async function tick(){if(!playing)return;slider.value=(Number(slider.value)+1)%groups[select.value].length;await show();if(playing)timer=setTimeout(tick,180)}
select.onchange=()=>{stop();slider.value=0;show()};slider.oninput=()=>{stop();show()};play.onclick=()=>{if(playing)stop();else{playing=true;play.textContent='暂停';tick()}};show();</script></html>'''.replace('DATA',json.dumps(groups,ensure_ascii=False))
(output/'index.html').write_text(page)
(output/'gallery.json').write_text(json.dumps({'source':str(source),'groups':{k:len(v) for k,v in groups.items()},'scope':'Same-state comparison, no optical-flow/interpolated/generated frames'},indent=2)+'\n')
print(str(output/'index.html'))

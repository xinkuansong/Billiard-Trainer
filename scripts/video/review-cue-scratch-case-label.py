from pathlib import Path
import json
from PIL import Image,ImageDraw
r=Path(__file__).resolve().parents[2];p=r/'output/cue-scratch-selection-20261005/r14-case-label-keyframes'
m=json.loads((p/'manifest.json').read_text());states=json.loads((p/'frame-states.json').read_text());old=json.loads((p.parent/'r13-black-pot-line/frame-states.json').read_text())
assert not m['exported'] and len(states)==len(old)
for s,o in zip(states,old):
    assert s['caseLabelHidden']==s['guidesHidden']==s['ghostHidden']
    assert {k:v for k,v in s.items() if k!='caseLabelHidden'}==o
for c in m['cases']:
    ss=[s for s in states if s['case']==c['id']]
    assert c['strokeStartFrame']==120
    assert all(not s['caseLabelHidden'] for s in ss[:120])
    assert all(s['caseLabelHidden'] for s in ss[120:])
# Contact sheet for comparing three native scene keyframes; original full-size PNGs retained.
items=[('M067',119,'1 - before stroke'),('M030',119,'4 - before stroke'),('M053',119,'6 - before stroke'),('M067',120,'1 - stroke starts')]
sheet=Image.new('RGB',(1440,670),(24,24,24));d=ImageDraw.Draw(sheet)
for col,(name,n,title) in enumerate(items):
    im=Image.open(p/f'{name}-{n:04d}.png');assert im.size==(1440,2560)
    sheet.paste(im.resize((360,640)),(col*360,30));d.text((col*360+12,8),title,fill='white')
sheet.save(p/'keyframe-comparison.jpg',quality=95)
labels=['一','二','三','四','五','六'];cards=[]
for c,num in zip(m['cases'],labels):
    cards.append(f'<article><h2>球形{num} · 静止展示</h2><a href="{c["id"]}-0119.png"><img src="{c["id"]}-0119.png"></a><details><summary>开始运杆：编号、线、假想球同时隐藏</summary><img src="{c["id"]}-0120.png"></details></article>')
(p/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>球形编号关键帧</title><style>body{background:#19211e;color:#eee;font:18px system-ui;padding:24px}main{display:grid;grid-template-columns:repeat(3,minmax(220px,1fr));gap:24px}img{width:100%}h2{font-size:20px}summary{cursor:pointer;padding:12px}a{color:#ffe329}</style><h1>球形编号 · 关键帧预览</h1><p>仅击球前1秒展示；从运杆起与轨迹线、假想球同步消失。原图1440×2560。</p><main>'+''.join(cards)+'</main>')
(p/'verification.json').write_text(json.dumps({'nativeTest':'stills.log','exportedVideo':False,'allSixVisibilityBoundariesPass':True,'motionAndTimingIdenticalToR13':True,'initialHoldSeconds':1,'hideAtLocalFrame':120,'frameRate':120,'labelRect':[36,260,300,120],'reviewFrames':items},ensure_ascii=False,indent=2))
print('PASS: six native label/guide/ghost boundaries; unchanged motion and timing.')

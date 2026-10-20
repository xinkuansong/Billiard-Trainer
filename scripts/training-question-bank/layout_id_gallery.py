#!/usr/bin/env python3
"""Read persisted combination IDs, reconstruct representative layouts and render review cards."""
import collections
import hashlib
import html
import json
import math
import zlib
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import grid_inventory_report as rules
import grid_anchor_gallery as gallery
from layout_combination_ids import entries

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'output/accuracy-layout-bank-v3-ids-20261021/grid-layouts-with-combinations.json'
OUT=ROOT/'output/accuracy-layout-id-review-20261021'


def main():
    OUT.mkdir(exist_ok=True);(OUT/'samples').mkdir(exist_ok=True)
    data=json.loads(SOURCE.read_text());picks={};rare=[];example=None;extra={}
    for ti,t in enumerate(data['targets']):
        for ordinal,mi,bit in entries(t,data['distanceSamples']):
            code=t['combinationIndices'][ordinal];cell=data['combinationTable'][code]
            key=(cell['angleIndex'],cell['pocketType'],cell['railIndex'])
            desired=(key[0]+key[2])%4 if not key[1] else 4+(key[0]+key[2])%2
            rank=(t['pocket']!=desired,t['source']!='grid',zlib.crc32(f"id-review:{t['inventoryTargetIndex']}:{mi}:{bit}".encode()))
            ref=(ti,ordinal,mi,bit)
            if key not in picks or rank<picks[key][0]:picks[key]=(rank,ref)
            for dim in ['cueIndex','objectIndex']:
                ekey=(dim,cell[dim])
                if ekey not in extra or rank<extra[ekey][0]:extra[ekey]=(rank,ref)
            if cell['pocketType']==1 and cell['railIndex']==2:rare.append(ref)
            if t['inventoryTargetIndex']==1927 and mi==79 and bit==1:example=ref
    selected=[picks[k][1] for k in sorted(picks)]
    for ref in rare+[example]:
        assert ref is not None
        if ref not in selected:selected.append(ref)
    for dim in ['cueIndex','objectIndex']:
        for value in range(3):
            if not any(data['combinationTable'][data['targets'][r[0]]['combinationIndices'][r[1]]][dim]==value for r in selected):
                ref=extra[dim,value][1]
                if ref not in selected:selected.append(ref)
    samples=[];images=[];cards=[]
    for number,(ti,ordinal,mi,bit) in enumerate(selected,1):
        t=data['targets'][ti];index=t['combinationIndices'][ordinal];stored=data['combinationTable'][index]
        o,g,p=(rules.point(t[k]) for k in ['object','ghost','aim'])
        backward=(g-o)/np.linalg.norm(g-o);beta=mi-85;a=math.radians(beta);gc=data['distanceSamples'][bit]
        c=g+gc*np.array([backward[0]*math.cos(a)-backward[1]*math.sin(a),backward[0]*math.sin(a)+backward[1]*math.cos(a)])
        co=float(np.linalg.norm(c-o));op=float(np.linalg.norm(p-o));gap=float(rules.rail_gap(o,data['geometry']))
        ai=next(i for i,limit in enumerate([10,30,50,70,85]) if abs(beta)<=limit)
        cell=dict(angleIndex=ai,pocketType=int(t['pocket']>=4),cueIndex=int(rules.band(co)),objectIndex=int(rules.band(op)),railIndex=2 if abs(gap)<=rules.EPSILON else 1 if gap<=.1+rules.EPSILON else 0)
        assert rules.cell_id(cell)==stored['id']
        for k,v in cell.items():assert stored[k]==v
        assert t['masks'][mi]&(1<<bit)
        assert abs(np.linalg.norm(g-o)-2*data['geometry']['radius'])<1e-7
        assert abs(np.linalg.norm(c-g)-gc)<1e-10
        # Restore the encoded parameters from coordinates as a roundtrip check.
        cp=(c-g)/np.linalg.norm(c-g)
        actual=math.degrees(math.atan2(backward[0]*cp[1]-backward[1]*cp[0],float(np.dot(backward,cp))))
        assert abs(actual-beta)<1e-8
        s=dict(cellID=stored['id'],cell=cell,combinationIndex=index,layoutOrdinal=ordinal,
            inventoryTargetIndex=t['inventoryTargetIndex'],maskIndex=mi,distanceBit=bit,
            pocket=t['pocket'],signedAngle=beta,source=t['source'],cue=dict(x=float(c[0]),z=float(c[1])),target=t['object'],ghost=t['ghost'],aim=t['aim'],gap=gap,cueDistance=co,objectDistance=op,gc=gc,pg=t['pg'],bearing=t['bearing'],clean=t['clean'],classificationMatches=True,
            screening='previous middle screen passed' if t['pocket']>=4 else 'geometry candidate only')
        im=gallery.sample_image(s,data['geometry'],number)
        draw=ImageDraw.Draw(im);draw.rectangle((0,532,900,600),fill='#f4f7f6')
        small=ImageFont.truetype(gallery.FONT,18)
        draw.text((24,539),f"存储编号 {index} → {stored['id']}  ·  分类核对一致",fill='#193d32',font=small)
        status='中袋：此前中杆五次筛选通过' if t['pocket']>=4 else '角袋：几何候选，未做进球验证'
        draw.text((24,568),status+'；线为几何参考，非实际轨迹',fill='#50675e',font=small)
        im.save(OUT/f'samples/{number:02d}.png');images.append(im)
        s['image']=f'samples/{number:02d}.png';samples.append(s)
        label=' × '.join([rules.ANGLES[ai],rules.POCKETS[cell['pocketType']],'母球'+rules.DISTANCES[cell['cueIndex']],'目标球距袋'+rules.DISTANCES[cell['objectIndex']],rules.RAILS[cell['railIndex']]])
        cards.append(f'''<article class="card" data-pocket="{cell['pocketType']}" data-rail="{cell['railIndex']}" data-angle="{ai}"><a href="{s['image']}" target="_blank"><img src="{s['image']}" loading="lazy" alt="{html.escape(label)}"></a><div class="details"><p>{label}</p><p><strong>保存的ID：{stored['id']}　✓ 实测分类一致</strong></p><details><summary>查看文件索引与还原坐标</summary><pre>{html.escape(json.dumps({k:s[k] for k in ['inventoryTargetIndex','maskIndex','distanceBit','layoutOrdinal','combinationIndex','cellID','cue','target','ghost','aim','pocket']},ensure_ascii=False,indent=2))}</pre></details></div></article>''')
    # Compare reconstructed middle samples against the original input coordinates and pass records.
    wanted={(s['inventoryTargetIndex'],s['maskIndex'],s['distanceBit']):s for s in samples if s['pocket']>=4}
    matched=0;middle=ROOT/'output/accuracy-middle-v3-20261021'
    request=json.loads((middle/'consumed-request.json').read_text())
    for bi,b in enumerate(request['batches']):
        inputs=json.loads((middle/b['file']).read_text())['samples']
        selected_here=[(i,s) for i,s in enumerate(inputs) if (s['targetIndex'],s['maskIndex'],s['distanceBit']) in wanted]
        if not selected_here:continue
        results=json.loads((middle/f'results-{bi:03d}.json').read_text())
        for i,s in selected_here:
            restored=wanted[s['targetIndex'],s['maskIndex'],s['distanceBit']]
            assert results[i].get('proof') and results[i]['cellID']==restored['cellID']==s['cellID']
            for ball in ['cue','target','ghost','aim']:
                for axis in ['x','z']:assert abs(restored[ball][axis]-s[ball][axis])<1e-12
            matched+=1
    assert matched==len(wanted)
    selectors=[]
    for key,name,labels in [('pocket','袋型',rules.POCKETS),('rail','库距',rules.RAILS),('angle','角度',rules.ANGLES)]:
        selectors.append(f'<label>{name}<select data-key="{key}" onchange="filterCards()"><option value="">全部</option>'+''.join(f'<option value="{i}">{label}</option>' for i,label in enumerate(labels))+'</select></label>')
    page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>球形还原与组合ID核对</title><style>body{max-width:1500px;margin:30px auto;padding:0 20px;background:#f4f7f6;color:#193d32;font:16px -apple-system,sans-serif}p{line-height:1.7}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}.card{border:1px solid #cadbd2;border-radius:12px;background:white;overflow:hidden}.card[hidden]{display:none}img{width:100%;display:block}.details{padding:0 20px 18px}pre{overflow:auto;font-size:13px}.filters{display:flex;gap:20px;flex-wrap:wrap}select{padding:9px;margin-left:8px}a{color:#286953}@media(max-width:850px){.grid{grid-template-columns:1fr}}</style><h1>从题库文件还原球形，核对保存的组合ID</h1>'''
    page+=f'<p>共{len(samples)}例，覆盖五档角度、六个实际袋口和短中长距离；包含筛选后仅剩的全部4个贴库中袋球形，以及此前展示的第2437号球形。直接读取带组合编号的无解题库，未重新生成球形、未新增物理求解。</p>'
    page+='<p>白球C＝母球，红球O＝目标球，蓝色空心G＝假想球，橙色P＝指定袋口生成基准。线条仅用于核对几何，不代表实际进球轨迹。此为数据审查图，假想球不代表练习页面的显示设置。</p>'
    page+='<p>每张图显示保存的组合ID与实测分类。角袋仍是未验证候选；中袋沿用此前的中杆筛选结果。</p><div class="filters">'+''.join(selectors)+'</div><p id="count"></p><div class="grid">'+''.join(cards)+'</div>'
    page+='''<script>function filterCards(){let n=0;let selects=[...document.querySelectorAll('select')];document.querySelectorAll('.card').forEach(c=>{c.hidden=!selects.every(s=>s.value===''||c.dataset[s.dataset.key]===s.value);if(!c.hidden)n++});document.getElementById('count').textContent=`显示 ${n} 个球形`;}filterCards();</script></html>'''
    (OUT/'球形还原核对.html').write_text(page)
    # A compact six-case overview for immediate inspection.
    indices=[]
    for pocket_type in [0,1]:
        for rail in [0,1,2]:
            indices.append(next(i for i,s in enumerate(samples) if s['cell']['pocketType']==pocket_type and s['cell']['railIndex']==rail))
    # Three columns by two rows; keep all labels readable on the full-size image.
    overview=Image.new('RGB',(1800,890),'#f4f7f6');d=ImageDraw.Draw(overview)
    d.text((24,18),'球形还原核对 · 角袋与中袋 × 离库／半贴库／贴库',font=ImageFont.truetype(gallery.FONT,30),fill='#193d32')
    for slot,i in enumerate(indices):overview.paste(images[i].resize((600,400),Image.Resampling.LANCZOS),((slot%3)*600,80+(slot//3)*400))
    overview.save(OUT/'六例概览.png')
    # Contact sheets containing every image, for full visual review.
    for batch in range((len(images)+8)//9):
        sheet=Image.new('RGB',(1800,1240),'#f4f7f6')
        for j,im in enumerate(images[batch*9:(batch+1)*9]):sheet.paste(im.resize((600,400),Image.Resampling.LANCZOS),((j%3)*600,30+(j//3)*400))
        sheet.save(OUT/f'审图-{batch+1}.png')
    summary=dict(source=str(SOURCE),sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),count=len(samples),
                 strata=len(picks),pockets=sorted({s['pocket'] for s in samples}),allFrozenMiddle=len(rare),
                 middleMatchedToOriginal=matched,allIDsMatch=True,noNewPhysics=True,samples=samples)
    (OUT/'review.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
    print(json.dumps({k:v for k,v in summary.items() if k!='samples'},ensure_ascii=False,indent=2))

if __name__=='__main__':main()

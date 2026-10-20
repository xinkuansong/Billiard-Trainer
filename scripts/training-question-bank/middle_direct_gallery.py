#!/usr/bin/env python3
"""Display audited direct routes from this run, plus complete combination counts."""
import collections, html, json, math, zlib
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import grid_anchor_gallery as renderer
import grid_inventory_report as rules
from layout_combination_ids import entries
from middle_direct_v4 import OUT, ROOT

def main():
    data=json.loads((OUT/'grid-layouts-with-combinations.json').read_text());audit=json.loads((OUT/'audit.json').read_text())
    pool=json.loads((OUT/'gallery-pool.json').read_text());rows=json.loads((OUT/'cell-results.json').read_text())
    bytarget={t['inventoryTargetIndex']:t for t in data['targets']}
    selections={}
    for e in pool:
        s=e['sample'];c=s['cell'];key=(c['angleIndex'],c['railIndex'],s['pocket'])
        rank=(e['role']!='retry',not e['result']['trials'][-1]['cuePocketed'],zlib.crc32(str(s['sampleIndex']).encode()))
        if key not in selections or rank<selections[key][0]:selections[key]=(rank,e)
    selected=[selections[k][1] for k in sorted(selections)]
    # Include recovered examples and scratch-positive controls explicitly, without duplicate layouts.
    for e in pool:
        if e['role']=='retry' and sum(x['role']=='retry' for x in selected)<4 and e not in selected:selected.append(e)
    image_dir=OUT/'samples';image_dir.mkdir(exist_ok=True);images=[];cards=[];export=[]
    for number,e in enumerate(selected,1):
        s=e['sample'];c=s['cell'];t=bytarget[s['targetIndex']]
        ordinal=next(o for o,mi,b in entries(t,data['distanceSamples']) if mi==s['maskIndex'] and b==s['distanceBit'])
        stored=data['combinationTable'][t['combinationIndices'][ordinal]];assert stored['id']==s['cellID']
        o,g,p=(rules.point(t[k]) for k in ['object','ghost','aim']);a=math.radians(s['maskIndex']-85);v=(g-o)/np.linalg.norm(g-o)
        cue=g+data['distanceSamples'][s['distanceBit']]*np.array([v[0]*math.cos(a)-v[1]*math.sin(a),v[0]*math.sin(a)+v[1]*math.cos(a)])
        assert np.linalg.norm(cue-rules.point(s['cue']))<1e-12
        path=json.loads((OUT/f"review-native-paths/{e['nativeIndex']}.json").read_text());assert path['route']=='direct-pot'
        assert all(q['time']<=path['captureTime'] for q in path['target'])
        assert np.linalg.norm(rules.point(path['target'][0])-o)<1e-6
        im=Image.new('RGB',(1000,660),'#f4f7f6');d=ImageDraw.Draw(im);font=lambda n:ImageFont.truetype(renderer.FONT,n)
        scale=320;xy=lambda p:(500+p[0]*scale,310+p[1]*scale)
        title=f"{number:02d} {renderer.POCKET_NAMES[s['pocket']]} · 切角{abs(s['signedAngle'])}° · {rules.RAILS[c['railIndex']]}"
        d.text((26,18),title,font=font(25),fill='#193d32')
        gap=rules.rail_gap(o,data['geometry']);co=np.linalg.norm(cue-o);op=np.linalg.norm(p-o)
        d.text((26,55),f"母球距离 {co:.2f}m   目标球距袋 {op:.2f}m   球面库距 {gap*100:.2f}cm",font=font(20),fill='#50675e')
        renderer.table(d,data['geometry'],xy,scale)
        d.line([xy(cue),xy(g)],fill='#408dc0',width=2)
        targetpath=[xy(rules.point(q)) for q in path['target']]
        if len(targetpath)>1:d.line(targetpath,fill='#e28624',width=3)
        r=data['geometry']['radius']*scale
        for ball,color,outline in [(cue,'white','#245c76'),(g,None,'#408dc0'),(o,'#e76150','#923b31')]:
            x,y=xy(ball);d.ellipse((x-r,y-r,x+r,y+r),fill=color,outline=outline,width=2)
        renderer.cross(d,xy,p)
        d.text((26,548),f"组合ID：{s['cellID']}   编号：{t['combinationIndices'][ordinal]}",font=font(20),fill='#193d32')
        d.text((26,581),f"直进核验通过 · 中杆 · 初速 {path['speed']:.5g}m/s · 母球{'进袋（允许）' if path['cuePocketed'] else '未进袋'}",font=font(20),fill='#193d32')
        d.text((26,617),'橙线：本次模拟的目标球轨迹；蓝线：母球初始瞄准方向',font=font(19),fill='#50675e')
        filename=f'samples/{number:02d}.png';im.save(OUT/filename);images.append(im)
        export.append(dict(number=number,globalSampleIndex=s['sampleIndex'],nativeIndex=e['nativeIndex'],cellID=s['cellID'],image=filename,storedCode=t['combinationIndices'][ordinal],speed=path['speed'],cuePocketed=path['cuePocketed']))
        cards.append(f'<article data-angle="{c["angleIndex"]}" data-rail="{c["railIndex"]}"><a href="{filename}" target="_blank"><img src="{filename}" loading="lazy" alt="{title}"></a><p>原球形索引 {s["sampleIndex"]} · {"重新搜索后找到直进力度" if e["role"]=="retry" else "本轮原生重放对照通过"}</p></article>')
    page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>直进筛选复核</title><style>body{max-width:1500px;margin:28px auto;padding:0 20px;font:17px -apple-system,sans-serif;background:#f4f7f6;color:#193d32}p{line-height:1.8}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}article{background:white;border:1px solid #cadbd2;border-radius:12px;overflow:hidden}article p{padding:0 20px}img{width:100%;display:block}a{color:#286953}select{padding:10px;margin:8px}article[hidden]{display:none}@media(max-width:800px){.grid{grid-template-columns:1fr}}</style><h1>中袋直进筛选 · 本次模拟实测球形</h1>'''
    page+=f'<p>中袋 {audit["previousMiddle"]:,} → <b>{audit["middle"]:,}</b>，移除 {audit["removed"]:,} 个原通过球形。排除绕库、其他袋口接触和二次碰撞；正常目标袋角接触与初始贴库压库允许，母球进袋忽略。每题中杆、固定方向、最多5次力度。</p>'
    page+=f'<p>以下{len(selected)}例全部在本轮实际重放，坐标从修正后文件读回核对。橙线为实际目标球轨迹，蓝线仅为初始瞄准方向。假想球供审查使用。原图05号和11号已剔除，详见<a href="组合分布.html">全部270组合的新旧数量</a>。</p>'
    for key,label,values in [('angle','角度',rules.ANGLES),('rail','库边',rules.RAILS)]:
        page+=f'<label>{label}<select data-key="{key}" onchange="filterCards()"><option value="">全部</option>'+''.join(f'<option value="{i}">{v}</option>' for i,v in enumerate(values))+'</select></label>'
    page+='<div class="grid">'+''.join(cards)+'</div><script>function filterCards(){document.querySelectorAll("article").forEach(c=>{c.hidden=![...document.querySelectorAll("select")].every(s=>s.value===""||c.dataset[s.dataset.key]===s.value)})}</script></html>'
    (OUT/'直进球形复核.html').write_text(page)
    (OUT/'render-samples.json').write_text(json.dumps(export,ensure_ascii=False,indent=2))
    for offset in range(0,len(images),6):
        sheet=Image.new('RGB',(1800,820),'#f4f7f6')
        for j,im in enumerate(images[offset:offset+6]):sheet.paste(im.resize((600,396),Image.Resampling.LANCZOS),((j%3)*600,(j//3)*410))
        sheet.save(OUT/f'审图-{offset//6+1}.png')
    # Six varied shapes for the inline summary, with no empty frozen-slot placeholders.
    six=[]
    for key in [(0,0),(1,1),(2,0),(3,1),(4,0),(4,1)]:
        found=next((i for i,e in enumerate(selected) if (e['sample']['cell']['angleIndex'],e['sample']['cell']['railIndex'])==key),None)
        if found is not None:six.append(found)
    for i in range(len(images)):
        if len(six)>=6:break
        if i not in six:six.append(i)
    overview=Image.new('RGB',(1800,850),'#f4f7f6')
    for slot,i in enumerate(six):overview.paste(images[i].resize((600,396),Image.Resampling.LANCZOS),((slot%3)*600,(slot//3)*410))
    overview.save(OUT/'直进六例.png')
    table=['<table><thead><tr>'+''.join(f'<th>{x}</th>' for x in ['袋型','角度','母球距离','目标球距袋','库边','几何候选','旧保留','新保留','减少','资格'])+'</tr></thead><tbody>']
    md=['|组合ID|旧保留|新保留|减少|资格|','|---|---:|---:|---:|---|']
    for row in rows:
        c=row['cell'];n=row['remaining'];status='直进筛选' if c['pocketType']==1 else '未求解候选'
        values=[rules.POCKETS[c['pocketType']],rules.ANGLES[c['angleIndex']],rules.DISTANCES[c['cueIndex']],rules.DISTANCES[c['objectIndex']],rules.RAILS[c['railIndex']],row['geometric'],row['previous'],n,row['removed'],status]
        table.append(f'<tr data-pocket="{c["pocketType"]}" data-count="{n}" data-removed="{row["removed"]}">'+''.join(f'<td>{html.escape(str(v))}</td>' for v in values)+'</tr>')
        md.append(f'|{row["cellID"]}|{row["previous"]}|{n}|{row["removed"]}|{status}|')
    table.append('</tbody></table>')
    head='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>修正后组合分布</title><style>body{max-width:1400px;margin:28px auto;padding:0 20px;font:16px -apple-system,sans-serif;background:#f4f7f6;color:#193d32}p{line-height:1.8}table{width:100%;border-collapse:collapse;background:white}td,th{padding:9px;border-bottom:1px solid #ddd;text-align:left}th{position:sticky;top:0;background:#dcece4}select{padding:8px;margin:8px}a{color:#286953}</style><h1>修正后全部270组合</h1>'''
    head+=f'<p>中袋 {audit["middle"]:,} / 272,710，通过率 {audit["middle"]/272710:.2%}。135个中袋组合中，{audit["occupied"]}个有题、{audit["atLeast500"]}个至少500题、{audit["empty"]}个无题。角袋580,804个保持未求解候选；合计{audit["total"]:,}个。</p><p>存储含组合ID、不含解：JSON {audit["jsonBytes"]:,}字节，gzip {audit["gzipBytes"]:,}字节。<a href="直进球形复核.html">查看本轮实测球形</a>。预算内未找到直进解不代表绝对无解。</p>'
    head+='<label>袋型<select id="pocket" onchange="filterRows()"><option value="1">中袋</option><option value="0">角袋</option><option value="">全部</option></select></label><label>数量<select id="count" onchange="filterRows()"><option value="all">全部</option><option value="changed">数量减少</option><option value="large">至少500题</option><option value="small">1～499题</option><option value="empty">0题</option></select></label>'
    head+=''.join(table)+'''<script>function filterRows(){let p=document.getElementById('pocket').value;let v=document.getElementById('count').value;document.querySelectorAll('tbody tr').forEach(r=>{let n=+r.dataset.count;r.hidden=!((p===''||r.dataset.pocket===p)&&(v==='all'||v==='changed'&&+r.dataset.removed>0||v==='large'&&n>=500||v==='small'&&n>0&&n<500||v==='empty'&&n===0))})}filterRows();</script></html>'''
    (OUT/'组合分布.html').write_text(head);(OUT/'组合分布.md').write_text('\n'.join(md))
    print(json.dumps(dict(samples=len(selected),images=len(images),contactSheets=math.ceil(len(images)/6)),ensure_ascii=False))
if __name__=='__main__':main()

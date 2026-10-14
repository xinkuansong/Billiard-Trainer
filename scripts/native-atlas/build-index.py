#!/usr/bin/env python3
"""Build a read-only, offline atlas from reviewed evidence and saved Figma receipts."""
import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--root', type=Path, default=Path('output/app-native-audit'))
p.add_argument('--figma-map', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
mapping = json.loads(a.figma_map.read_text())
frames = {(f['slotId'], f['sha256']): f for f in mapping['frames']}
paths = subprocess.check_output(['rg', '--files', '--hidden', str(a.root),
    '-g', '*review*.json', '-g', '!**/Products/**', '-g', '!**/frozen-products/**',
    '-g', '!**/packages/**'], text=True).splitlines()
records = {}
for name in sorted(paths):
    source = Path(name)
    manifest = json.loads(source.read_text())
    if not isinstance(manifest, dict):
        continue
    # Relocatable backup manifests are copies of reviewed evidence, with paths
    # relative to their bundle. They must not create new atlas records.
    if manifest.get('manifestKind') == 'NATIVE_ATLAS_RECOVERY_MATERIAL':
        continue
    for e in manifest.get('images', []):
        if e.get('status') != 'VALIDATED':
            continue
        path = Path(e['path'])
        if hashlib.sha256(path.read_bytes()).hexdigest() != e['sha256']:
            raise ValueError('Reviewed image changed: ' + str(path))
        e = dict(e)
        if not all(e.get(k) for k in ('device', 'orientation', 'theme')) and e.get('metadata'):
            # Early reviewed manifests predate these fields. Recover only from
            # captured metadata, retaining the original manifest and slot ID.
            metadata = json.loads(Path(e['metadata']).read_text())
            window = metadata.get('window', {})
            w, h = window.get('width'), window.get('height')
            device = {(375, 667): 'small', (402, 874): 'standard',
                      (440, 956): 'large', (834, 1210): 'pad'}.get(tuple(sorted((w, h)))) if w and h else None
            for field, value in dict(device=device,
                    orientation=('portrait' if h > w else 'landscape') if w and h else None,
                    theme=metadata.get('appearance')).items():
                if not e.get(field) and value:
                    e[field] = value
            e['environmentMetadataSource'] = e['metadata']
        key = (e['slotId'], e['sha256'])
        if key in records:
            records[key]['reviewManifests'].append(str(source.resolve()))
            continue
        frame = frames.get(key)
        records[key] = dict(e, src=os.path.relpath(path, a.output),
            reviewManifests=[str(source.resolve())],
            figmaURL=('https://www.figma.com/design/' + mapping['fileKey'] +
                      '/?node-id=' + frame['frame'].replace(':', '-')) if frame else None,
            figmaReceipt=frame.get('receipt') if frame else None)
entries = sorted(records.values(), key=lambda e: (e.get('page', ''), e['slotId'], e['captureId']))
index = dict(images=entries, baseline='f75cbafdc455e5521a248d2187943956456dcaaa',
             confirmedFigmaFrames=len(mapping['frames']), userAcceptance=False,
             note='Reviewed native images, including historical revisions and long-page slices. Counts are not page or acceptance totals.')
(a.output/'index.json').write_text(json.dumps(index, ensure_ascii=False, indent=2)+'\n')
data = json.dumps(index, ensure_ascii=False).replace('<', '\\u003c')
document = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>球迹 · 原生截图图册</title>
<style>body{margin:0;background:#f3f4f2;color:#19241e;font:15px system-ui}header{padding:24px 28px;background:white;border-bottom:1px solid #d7ddd7}h1{font-size:25px;margin:0 0 10px}p{line-height:1.6;margin:8px 0}nav{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}select,input,button{font:inherit;padding:9px;border:1px solid #b9c6be;border-radius:7px;background:white}input{min-width:240px}main{padding:24px;display:flex;gap:24px;align-items:flex-start;flex-wrap:wrap}article{background:white;border:1px solid #d7ddd7;border-radius:10px;overflow:hidden;width:360px}article.wide{width:660px}article img{display:block;width:100%;height:auto}article div{padding:14px}article p{font-size:13px;overflow-wrap:anywhere}a{color:#176640}small{color:#64716a}footer{padding:10px 24px 30px}#count{font-weight:600}</style>
<header><h1>球迹 · 原生截图图册</h1><p>冻结 App：f75cbafd · 以下图片已做 AI 逐图核对，保留 App 实际问题。<strong>没有登记用户验收。</strong></p><p id="count"></p><small>数量包含长页切片和历史修订，不是页面覆盖率。Figma 链接仅来自已保存的导入回执；没有链接的图片仍可在本地评审。</small><nav><select id="page"><option value="">全部业务</option></select><select id="device"><option value="">全部设备</option></select><select id="theme"><option value="">全部主题</option></select><input id="q" placeholder="搜索页面、状态或 captureId" aria-label="搜索截图"><select id="imported"><option value="">全部导入状态</option><option value="yes">已保存 Figma 回执</option><option value="no">尚无保存回执</option></select></nav></header><main id="grid"></main><footer><button id="more">继续显示</button><p>这是只读索引，不会自动登记认可或改动原图。<a href="index.json">下载完整索引</a></p></footer>
<script>const DATA=__DATA__;const rows=DATA.images;const $=id=>document.getElementById(id);const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));let limit=36;
for(const key of ['page','device','theme']){for(const value of [...new Set(rows.map(e=>e[key]).filter(Boolean))].sort()){const o=document.createElement('option');o.value=value;o.textContent=value;$(key).append(o)}}
function render(){const q=$('q').value.toLowerCase();const filtered=rows.filter(e=>['page','device','theme'].every(k=>!$(k).value||e[k]===$(k).value)&&(!q||[e.label,e.pageName,e.slotId,e.captureId].join(' ').toLowerCase().includes(q))&&(!$('imported').value||Boolean(e.figmaURL)===($('imported').value==='yes')));$('count').textContent=`本地已核对 ${rows.length} 张 · Figma 保存回执 ${DATA.confirmedFigmaFrames} 个画板 · 当前筛选 ${filtered.length} 张`;$('grid').innerHTML=filtered.slice(0,limit).map(e=>`<article class="${e.width>e.height?'wide':''}"><a href="${esc(e.src)}" target="_blank"><img loading="lazy" src="${esc(e.src)}" alt="${esc(e.label)}"></a><div><b>${esc(e.pageName||e.pageId)}</b><p>${esc(e.label)}</p><small>${esc(e.captureId)}</small><p>${e.figmaURL?`<a target="_blank" href="${esc(e.figmaURL)}">打开 Figma 画板</a>`:'Figma 回执尚未保存'} · 用户待评审${e.partialWorkflow?' · 此图有效，所属流程未完整通过':''}${e.coverageStatus==='FIRST_VIEWPORT_ONLY'?' · 仅首屏有效，下方内容待补':''}</p></div></article>`).join('');$('more').hidden=limit>=filtered.length}
for(const key of ['page','device','theme','q','imported'])$(key).addEventListener('input',()=>{limit=36;render()});$('more').onclick=()=>{limit+=36;render()};render();</script></html>'''
(a.output/'index.html').write_text(document.replace('__DATA__', data))
print(json.dumps({'reviewedImages': len(entries), 'savedFigmaFrames': len(mapping['frames']),
                  'withSavedReceipt': sum(bool(e['figmaURL']) for e in entries),
                  'index': str((a.output/'index.html').resolve())}))

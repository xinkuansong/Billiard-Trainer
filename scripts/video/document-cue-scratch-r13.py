from pathlib import Path
import json,hashlib
r=Path(__file__).resolve().parents[2];p=r/'output/cue-scratch-selection-20261005/r13-black-pot-line'
m=json.loads((p/'manifest.json').read_text());v=json.loads((p/'verification.json').read_text());master=p/'V023-six-full-shots-120fps.mp4';probe=v['media'][0]['probe'];bit=int(probe['streams'][0]['bit_rate'])/1e6
rows='\n'.join(f"| {c['id']} | {c['impactTime']:.3f} | {c['bothDropFrame']/120:.3f} | {c['duration']:.3f} |" for c in m['cases'])
report=f'''# V023 r13 黑色进球线版

1440×2560，原生120fps，{m['frames']}帧 / {m['duration']:.6f}秒；H.264 + AAC 48kHz双声道。实际视频码率{bit:.3f}Mbps（编码请求64Mbps），文件{master.stat().st_size/1e6:.2f}MB。

本版仅将六段目标球进球线改为黑色，母球轨迹仍为白色。

时间顺序：球形静止1秒 → 运杆（起始即隐藏辅助线与假想球）→ 原生击球及完整落袋下沉 → 1秒交叉淡化。五处过渡无黑场，下个球形完全进入后再静止1秒。末段两球下沉完成后停0.3秒直接结束。

修复FL-116：不再把球顶低于台面作为停止条件；统一等待每球production collection tail结束，若生产尾段带淡出则等待淡出完成。六例均为采样袋网尾段，球继续落到原生袋网支撑位置，并非提前隐藏节点。旧r11取消静帧不能修复此问题，已中止。

| 球形 | 击球时刻（段内秒） | 两球完成（段内秒） | 独立片段秒 |
|---|---:|---:|---:|
{rows}

验证：export.log共1项原生测试、0失败；运动状态与时间轴逐项等于r12；3430帧PTS及120fps运动采样，五处600帧交叉淡化、7个视频完整解码/音轨/视频流负载保持、红打点/黑八/相机物理一致性检查通过。每球结束位置与生产tail.end逐坐标核对通过。袋口静帧对比及编码MP4双袋口近景见pocket-review.jpg、pocket-review-encoded.jpg；编码帧目视复核单列于验收记录。

声音：复用r8已选本地试听音效与原生接触事件，按新版时间轴重新混音，无BGM或旁白。响度与解码验证不替代用户听感验收。

封面：../cover-r2-black-line/cover.png，941×1672，黄底黑字，目标球进球线同步改黑。未发布、未归入待发布。保留旧版，不改变App物理、相机与袋网呈现默认行为。
'''
(p/'REPORT.md').write_text(report)
items=''.join(f'<p>{c["id"]}</p><video controls preload="metadata" src="{c["id"]}-120fps.mp4"></video>' for c in m['cases'])
(p/'index.html').write_text(f'''<!doctype html><meta charset="utf-8"><title>V023 完整落袋版</title><style>body{{background:#171b18;color:#eee;font:18px system-ui;max-width:900px;margin:32px auto}}video{{width:360px;max-width:95vw}}a{{color:#aadcc0}}</style><h1>V023 黑色进球线版</h1><p><a href="../cover-r2-black-line/cover.png">黄底黑字封面</a></p><p>球形展示1秒 · 两球完整下沉后1秒交叉淡化 · 1440×2560 / 120fps / {m['duration']:.2f}秒</p><video controls src="{master.name}"></video><p><a href="REPORT.md">验证报告</a></p>{items}''')
files=[master,p/'fixture.swift',p/'manifest.json',p/'verification.json']+[r/'scripts/video'/n for n in ['cue-scratch-selection-black-line.swift','run-cue-scratch-black-line.py','finish-cue-scratch-r13.py','review-cue-scratch-pockets-r13.py']]
(p/'source-hashes.json').write_text(json.dumps({str(f.relative_to(r)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files},indent=2))
print(bit,master.stat().st_size,m['duration'])

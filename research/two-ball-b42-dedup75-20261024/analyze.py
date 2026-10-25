from pathlib import Path
import json,math,hashlib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/two-ball-b42-dedup75-20261024'
original=json.loads((ROOT/'output/two-ball-multi-position-top10-20261024/B42-ranking.json').read_text())
native=json.loads((OUT/'native-result.json').read_text())
rows=original['rows'];assert len(rows)==93
ids=[q['comboIndex'] for q in rows]
assert ids==[q['comboIndex'] for q in native['rows']]
assert len(native['pairs'])==93*92//2
lookup={tuple(sorted((q['a'],q['b']))):q for q in native['pairs']}
assert len(lookup)==4278
for q in lookup.values():
    assert 0<=q['score']<=100 and math.isclose(q['score'],100*2**(-(.7*q['meanDTWCM']+.3*q['frechetCM'])/20),abs_tol=1e-10)
previous=json.loads((ROOT/'output/two-ball-b42-similarity-20261024/pairwise-similarity.json').read_text())
for q in previous['pairs']:
    now=lookup[tuple(sorted((q['a'],q['b'])))];assert math.isclose(q['score'],now['score'],abs_tol=1e-9)
kept=[];removed=[]
for old in rows:
    q=dict(old);q['oldRank']=old['rank']
    matches=[]
    for k in kept:
        pair=lookup[tuple(sorted((q['comboIndex'],k['comboIndex'])))];matches.append((k,pair))
    similar=[(k,pair) for k,pair in matches if pair['score']>=75]
    if similar:
        k,pair=similar[0]
        q['matchedRepresentative']=k['comboIndex'];q['matchedRepresentativeRank']=k['rank'];q['similarity']=pair['score']
        q['allSimilarRepresentatives']=[dict(comboIndex=k['comboIndex'],score=pair['score']) for k,pair in similar]
        removed.append(q)
    else:
        q['rank']=len(kept)+1
        q['maxSimilarityToEarlierRetained']=max((pair['score'] for k,pair in matches),default=None)
        kept.append(q)
assert len(kept)+len(removed)==93
assert all(lookup[tuple(sorted((a['comboIndex'],b['comboIndex'])))]['score']<75 for i,a in enumerate(kept) for b in kept[i+1:])
assert all(q['similarity']>=75 and next(k['oldRank'] for k in kept if k['comboIndex']==q['matchedRepresentative'])<q['oldRank'] for q in removed)
assert [q['evaluation']['best']['score'] for q in kept]==sorted(q['evaluation']['best']['score'] for q in kept)
result=dict(cellID=42,position=original['position'],threshold=75,originalValidCount=93,keptCount=len(kept),removedCount=len(removed),rule='ascending original second-shot score then comboIndex; reject if similarity >=75 with any retained representative; all 93 processed before top10',scoreVersion=native['pairs'][0]['version'],pairCount=4278,rows=kept,removed=removed)
(OUT/'dedup-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
lines=['# B42：75分相似阈值去重后取前十','',f'原始第一杆有效95组 → 途中碰B42过滤后93组 → 75分相似度去重保留{len(kept)}条代表路线，合并{len(removed)}组 → 取前十。','', '按既有第二杆几何难度升序（同分按comboIndex）检查；与任一已保留代表相似度≥75即合并，否则保留。全部93组均已处理，代表之间两两相似度均<75。只与保留代表比较，不进行传递式连通分组。没有加入第一杆力度、杆法权重。','', '直接复用分离角练习的碰后轨迹提取和评分；70%平均DTW＋30%Fréchet，20cm为50分尺度。93组共4,278对原生评分，原前十45对与上一轮一致。原始93组重跑字段一致，完整预测停点与旧值<1微米；原数据、旧图与旧排序不覆盖。','', '|新排名|原排名|组合ID|第二杆难度S|杆速m/s|左右/高低打点|吃库|','|---:|---:|---:|---:|---:|---|---:|']
for q in kept:
    lines.append(f"|{q['rank']}|{q['oldRank']}|{q['comboIndex']}|{q['evaluation']['best']['score']:.6f}|{q['velocity']:.3f}|{q['spinX']:+.3f} / {q['spinY']:+.3f}|{q['mainRails']}|")
lines+=['','## 被合并的组合','','|原排名|组合|保留代表|相似度|','|---:|---:|---:|---:|']
for q in removed:lines.append(f"|{q['oldRank']}|{q['comboIndex']}|{q['matchedRepresentative']}|{q['similarity']:.3f}|")
lines+=['','[前十叠加图](B42-top10.png) · [逐组分图](B42-individual.png) · [去重明细JSON](dedup-result.json) · [原生轨迹与4278对分数](native-result.json) · [一致性检查](native-validation.json)','', '仍是固定B42条件下的原路径扫掠过滤和路线去重，未验证三球重模拟、第二杆进袋或扰动稳定性。']
(OUT/'README.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(dict(kept=len(kept),removed=len(removed),top10=[dict(rank=q['rank'],oldRank=q['oldRank'],combo=q['comboIndex']) for q in kept[:10]]),ensure_ascii=False))

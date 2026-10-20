#!/usr/bin/env python3
"""Reproducible sampling study, not App integration or physics qualification."""
import bisect, collections, hashlib, html, json, math, random
from pathlib import Path
import numpy as np
from layout_combination_ids import entries
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'output/accuracy-middle-direct-v4-20261021/grid-layouts-with-combinations.json'
OUT=ROOT/'output/accuracy-weight-review-20261021'
AXES=['angleIndex','pocketType','cueIndex','objectIndex','railIndex']
NAMES=['切角','袋型','母球距离','目标球距袋','库边情况']
LABELS=[['近直球0–10°','小角度11–30°','中角度31–50°','大角度51–70°','极薄球71–85°'],['角袋','中袋'],['短','中','长'],['短','中','长'],['离库','半贴库','贴库']]
WEIGHTS=[[.15,.25,.30,.20,.10],[.60,.40],[.30,.45,.25],[.30,.45,.25],[.70,.20,.10]]
SEED=20261021;ROUNDS=10000;PER_ROUND=20

def dump(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2))
def marginal(cells,p):return [np.bincount(cells[:,i],weights=p,minlength=len(w)).tolist() for i,w in enumerate(WEIGHTS)]

def sequential(cells,available=None):
    avail=list(range(len(cells))) if available is None else available
    p=np.zeros(len(cells))
    def visit(indices,depth,prob):
        if depth==5:
            assert len(indices)==1;p[indices[0]]=prob;return
        groups=collections.defaultdict(list)
        for i in indices:groups[int(cells[i,depth])].append(i)
        z=sum(WEIGHTS[depth][v] for v in groups)
        for v,group in groups.items():visit(group,depth+1,prob*WEIGHTS[depth][v]/z)
    visit(avail,0,1.)
    assert abs(p.sum()-1)<1e-12
    return p

def calibrated(cells):
    # Keep the angle × pocket joint target, plus the three later global marginals.
    p=np.prod(np.stack([np.array(w)[cells[:,i]] for i,w in enumerate(WEIGHTS)]),axis=0);p/=p.sum()
    constraints=[(cells[:,0]*2+cells[:,1],np.outer(WEIGHTS[0],WEIGHTS[1]).ravel())]+[(cells[:,i],np.array(WEIGHTS[i])) for i in [2,3,4]]
    for iteration in range(10000):
        for group,target in constraints:
            current=np.bincount(group,weights=p,minlength=len(target));assert np.all(current>0)
            p*=(target/current)[group]
        error=max(float(np.max(abs(np.bincount(group,weights=p,minlength=len(target))-target))) for group,target in constraints)
        if error<1e-12:break
    assert error<1e-12
    return p,dict(iterations=iteration+1,maxMarginalError=error)

def simulate(cells,counts,prob,strategy):
    rng=random.Random(SEED);total=np.zeros(len(cells),dtype=np.int64)
    batches=[np.zeros((ROUNDS,len(w)),dtype=np.int16) for w in WEIGHTS]
    first=[];exhausted_switches=0;repeat_redraws=0;repeated_on_following_round=0;previous=set()
    cdf=np.cumsum(prob).tolist();cdf[-1]=1.
    for batch in range(ROUNDS):
        used=collections.defaultdict(set);remaining_cdf=cdf;ids=list(range(len(cells)));this_round=set()
        for position in range(PER_ROUND):
            i=bisect.bisect_left(remaining_cdf,rng.random())
            while len(used[i])>=counts[i]:
                exhausted_switches+=1
                live=[j for j in ids if len(used[j])<counts[j]]
                q=sequential(cells,live) if strategy=='sequential' else np.array([prob[j] if j in live else 0 for j in ids]);q/=q.sum()
                remaining_cdf=np.cumsum(q).tolist();remaining_cdf[-1]=1.
                i=bisect.bisect_left(remaining_cdf,rng.random())
            rank=rng.randrange(int(counts[i]))
            while rank in used[i]:repeat_redraws+=1;rank=rng.randrange(int(counts[i]))
            used[i].add(rank);assert (i,rank) not in this_round;this_round.add((i,rank))
            if (i,rank) in previous:repeated_on_following_round+=1
            total[i]+=1
            for axis in range(5):batches[axis][batch,cells[i,axis]]+=1
            if batch==0:first.append(dict(cellIndex=i,rankWithinCombination=rank))
        assert len(this_round)==PER_ROUND;previous=this_round
    actual=marginal(cells,total/(ROUNDS*PER_ROUND));bounds=[]
    for axis,ar in enumerate(batches):
        bounds.append([dict(p05=int(np.quantile(ar[:,v],.05,method='lower')),p95=int(np.quantile(ar[:,v],.95,method='higher')),zeroRounds=int((ar[:,v]==0).sum())) for v in range(ar.shape[1])])
    assert total.sum()==ROUNDS*PER_ROUND
    # The small independent-bank sample has expected random fluctuation; use a broad 6-SE envelope.
    for i,w in enumerate(marginal(cells,prob)):
        for j,p in enumerate(w):assert abs(actual[i][j]-p)<6*math.sqrt(p*(1-p)/(ROUNDS*PER_ROUND))+.0001
    return dict(actual=actual,batchRanges=bounds,first20=first,cellDraws=total.tolist(),exhaustedCellSwitches=exhausted_switches,duplicateRedraws=repeat_redraws,exactDuplicatesWithinRound=0,exactRepeatsFromPreviousRound=repeated_on_following_round)

def main():
    OUT.mkdir(exist_ok=True);data=json.loads(SRC.read_text());table=data['combinationTable'];count=collections.Counter()
    for t in data['targets']:
        assert len(t['combinationIndices'])==sum(m.bit_count() for m in t['masks'])
        count.update(t['combinationIndices'])
    rows=json.loads((SRC.parent/'cell-results.json').read_text());expected={r['cellID']:r['remaining'] for r in rows}
    assert len(table)==270 and sum(count.values())==782528
    assert all(count[i]==expected[c['id']] for i,c in enumerate(table))
    codes=[i for i in range(270) if count[i]];cells=np.array([[table[i][a] for a in AXES] for i in codes]);counts=np.array([count[i] for i in codes]);p=sequential(cells);q,fit=calibrated(cells)
    # Independent closed-form cross-check for the priority tree.
    for k,c in enumerate(cells):
        theoretical=1.
        for axis in range(5):
            options={other[axis] for other in cells if np.array_equal(other[:axis],c[:axis])}
            theoretical*=WEIGHTS[axis][c[axis]]/sum(WEIGHTS[axis][v] for v in options)
        assert abs(p[k]-theoretical)<1e-14
    ideal_products=np.array([math.prod(WEIGHTS[j][c[a]] for j,a in enumerate(AXES)) for c in table]);empty_mass=sum(ideal_products[i] for i in range(270) if not count[i])
    product=ideal_products[codes];product/=product.sum()
    original=simulate(cells,counts,p,'sequential');adjusted=simulate(cells,counts,q,'calibrated')
    summary=dict(seed=SEED,rounds=ROUNDS,perRound=PER_ROUND,drawsPerStrategy=ROUNDS*PER_ROUND,source=str(SRC),sourceSHA256=hashlib.sha256(SRC.read_bytes()).hexdigest(),
        totalLayouts=sum(count.values()),occupiedCells=len(codes),emptyCells=270-len(codes),emptyNominalProbability=empty_mass,
        axes=AXES,names=NAMES,labels=LABELS,weights=WEIGHTS,fit=fit,
        sequential=dict(theoretical=marginal(cells,p),**original),calibrated=dict(theoretical=marginal(cells,q),**adjusted),
        naiveRejectEmpty=marginal(cells,product),
        caveats=['Corners are geometry-only candidates; no physics simulations or App code changes.',
                 'No exact duplicate within each 20-shot round; long-term recent-history and adjacent-mirror avoidance not modeled.',
                 'Calibration is an offline comparison, not an approved implementation change. All figures describe current bank support.'])
    combo=[]
    for i,code in enumerate(codes):
        combo.append(dict(code=code,id=table[code]['id'],count=int(counts[i]),sequentialProbability=float(p[i]),calibratedProbability=float(q[i]),
                          sequentialDraws=original['cellDraws'][i],calibratedDraws=adjusted['cellDraws'][i],calibratedExpectedDrawsPerLayout=float(q[i]*200000/counts[i])))
    # Resolve the first 20 sampled within-combination ranks to real bank mask references.
    lookup=collections.defaultdict(list)
    for strategy,result in [('sequential',original),('calibrated',adjusted)]:
        for number,r in enumerate(result['first20'],1):lookup[(codes[r['cellIndex']],r['rankWithinCombination'])].append((strategy,number))
    cursor=collections.Counter();samples=[]
    for t in data['targets']:
        for ordinal,mi,bit in entries(t,data['distanceSamples']):
            code=t['combinationIndices'][ordinal];key=(code,cursor[code]);cursor[code]+=1
            for strategy,number in lookup.get(key,[]):
                samples.append(dict(strategy=strategy,number=number,cellID=table[code]['id'],code=code,cell={a:table[code][a] for a in AXES},
                    inventoryTargetIndex=t['inventoryTargetIndex'],maskIndex=mi,distanceBit=bit,pocket=t['pocket'],layoutOrdinal=ordinal))
    assert len(samples)==40
    samples.sort(key=lambda x:(x['strategy'],x['number']))
    dump(OUT/'summary.json',summary);dump(OUT/'combination-probabilities.json',combo);dump(OUT/'first-20-layouts.json',samples)
    render(summary,combo,samples)
    print(json.dumps({k:summary[k] for k in ['drawsPerStrategy','occupiedCells','emptyCells','emptyNominalProbability','fit']},ensure_ascii=False,indent=2))
    for i,name in enumerate(NAMES):print(name,'target',WEIGHTS[i],'sequential',original['actual'][i],'calibrated',adjusted['actual'][i])
    print('empty exhaustion',original['exhaustedCellSwitches'],adjusted['exhaustedCellSwitches'],'repeat prior',original['exactRepeatsFromPreviousRound'],adjusted['exactRepeatsFromPreviousRound'])

def render(s,combo,samples):
    fmt=lambda x:f'{100*x:.2f}%'
    heads=['条件','目标','原顺序：理论','原顺序：20万题实测','校准对照：20万题实测','原顺序偏差','对照偏差','原顺序20题轮次90%区间']
    body=[];md=['# 默认随机权重模拟','',f'每种方法{ROUNDS}轮×20题，共200000题；固定seed={SEED}。','', '| '+' | '.join(heads)+' |','|'+'---|'*len(heads)]
    for i,name in enumerate(NAMES):
        for j,label in enumerate(LABELS[i]):
            actual=s['sequential']['actual'][i][j];new=s['calibrated']['actual'][i][j];target=WEIGHTS[i][j];b=s['sequential']['batchRanges'][i][j]
            values=[name+' · '+label,fmt(target),fmt(s['sequential']['theoretical'][i][j]),fmt(actual),fmt(new),f'{100*(actual-target):+.2f}个百分点',f'{100*(new-target):+.2f}个百分点',f'{b["p05"]}～{b["p95"]}题']
            body.append('<tr>'+''.join('<td>'+html.escape(v)+'</td>' for v in values)+'</tr>');md.append('| '+' | '.join(values)+' |')
    page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>随机权重抽样对比</title><style>body{max-width:1500px;margin:32px auto;padding:0 22px;font:17px -apple-system,sans-serif;background:#f4f7f6;color:#193d32}p{line-height:1.8}table{width:100%;border-collapse:collapse;background:white;font-size:15px}th,td{padding:10px;border-bottom:1px solid #ddd;text-align:left}th{background:#dcece4;position:sticky;top:0}details{margin:20px 0}select{padding:8px}a{color:#286953}.note{background:#fff1d8;padding:16px;border-radius:8px}.scroll{overflow:auto}</style><h1>随机权重 · 空组合影响实测</h1>'''
    page+=f'<p>每种方案抽取<b>200,000题</b>（10,000轮×20题），共40万次；同一轮具体球形不重复，组合内均匀随机。题库782,528球形、270组合，其中178有题、92为空。若先独立抽五个条件，约<b>{s["emptyNominalProbability"]:.2%}</b>概率落到空组合。</p>'
    page+='<p class="note">本次是分布模拟：角袋580,804个仍是未做物理验证的候选。结果不能代替角袋进球验证；其验证后组合支持若改变，须重新统计。未修改App抽题器或题库。</p>'
    page+='<p><b>原顺序</b>：角度→袋型→母球距离→目标球距袋→库边。每层先排除无法形成有题组合的选项，再按该层权重重分配。<b>校准对照</b>：同一套目标权重，在178个有效组合上迭代调整组合概率，同时保持角度×袋型联合比例及其余三维总体比例；这是离线对照，尚未作为实现方案确认。</p>'
    page+='<p>结论：原顺序主要把库边分布推向离库（理论80.27%，目标70%），目标球长距离也被压低（理论19.35%，目标25%）。保留目标权重并校准组合概率，可在当前有效组合上消除这一结构性偏差；无需补空组合或按题量分配概率。</p>'
    page+='<div class="scroll"><table><thead><tr>'+''.join('<th>'+h+'</th>' for h in heads)+'</tr></thead><tbody>'+''.join(body)+'</tbody></table></div>'
    page+='<p>百分比为长期频率；一轮20题不保证精确配额。“90%区间”为1万轮的第5～95百分位题数。没有模拟跨轮近期避重和镜像相邻避让，不能把本轮不重复解释为长期不会重复。</p>'
    for method,title in [('sequential','原顺序首轮20题'),('calibrated','校准对照首轮20题')]:
        page+=f'<details><summary>{title}（固定种子，未挑选）</summary><table><tr><th>题号</th><th>组合ID</th><th>角度</th><th>袋型</th><th>母球距离</th><th>目标球距袋</th><th>库边</th></tr>'
        for x in samples:
            if x['strategy']!=method:continue
            vals=[str(x['number']),x['cellID']]+[LABELS[i][x['cell'][a]] for i,a in enumerate(AXES)]
            page+='<tr>'+''.join('<td>'+v+'</td>' for v in vals)+'</tr>'
        page+='</table></details>'
    page+='<details><summary>178个有效组合概率和样本次数</summary><table><tr><th>组合ID</th><th>题数</th><th>原顺序概率</th><th>校准概率</th><th>原顺序抽到</th><th>校准抽到</th><th>校准每球形平均曝光/20万题</th></tr>'
    for c in combo:
        vals=[c['id'],str(c['count']),fmt(c['sequentialProbability']),fmt(c['calibratedProbability']),str(c['sequentialDraws']),str(c['calibratedDraws']),f"{c['calibratedExpectedDrawsPerLayout']:.2f}"]
        page+='<tr>'+''.join('<td>'+v+'</td>' for v in vals)+'</tr>'
    page+='</table></details><p>可复算数据：<a href="summary.json">汇总与轮次波动</a> · <a href="combination-probabilities.json">组合概率</a> · <a href="first-20-layouts.json">首轮真实球形索引</a></p></html>'
    (OUT/'随机权重模拟.html').write_text(page);(OUT/'抽样报告.md').write_text('\n'.join(md)+'\n')

if __name__=='__main__':main()

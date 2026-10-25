"""One-layout endpoint/second-ball cross evaluation; no physics or bank edits."""
from pathlib import Path
import sys, json, gzip, math, hashlib
from collections import Counter
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import fontManager
from matplotlib.colors import LogNorm

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import Geometry
from filter_second_ball_preview import score, independent_score, POCKET_NAMES

OUT = ROOT/'output/two-ball-second-difficulty-20261024'
FULL = ROOT/'output/two-ball-strike-sampled100-20261024'
BANK = ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json'
CANDIDATES = ROOT/'output/two-ball-second-candidates-20261024/second-ball-candidates.jsonl'
LID = 'grid-v3:1512:68:1'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    OUT.mkdir(exist_ok=True)
    boards = json.loads((FULL/'layouts.json').read_text())
    idx = next(i for i, b in enumerate(boards) if b['id'] == LID)
    schedule = json.loads((FULL/'schedule.json').read_text())
    part = FULL/f'parts/{schedule.index(idx)//100:05}.jsonl.gz'
    with gzip.open(part, 'rt') as f:
        original = next(r for line in f if (r := json.loads(line))['id'] == LID)
    with CANDIDATES.open() as f:
        candidates = next(r['candidates'] for line in f if (r := json.loads(line))['id'] == LID)
    source_hashes = {str(p.relative_to(ROOT)): digest(p) for p in [BANK, CANDIDATES, part]}
    bank = json.loads(BANK.read_text())
    geo = bank['geometry']
    g = Geometry(geo['length'], geo['width'], geo['radius'])
    anchors = g.anchors()
    board = original['board']
    trials = [r for r in original['rows'] if r['usableForPositionMatch']]
    assert len({r['comboIndex'] for r in trials}) == len(trials)
    assert all(r['status'] == 'success' and r['cueStopValid'] for r in trials)
    # Known 0/45-degree approach directions relative to the object-to-pocket line.
    for angle in [0, 45]:
        a = math.radians(angle)
        cue = [-2*g.radius-math.cos(a), -math.sin(a)]
        m = score(cue, [0, 0], [1, 0], g.radius, 0)
        assert math.isclose(m['angle'], angle, abs_tol=1e-10)
        assert math.isclose(m['score'], 1/math.cos(a), rel_tol=1e-10)
    matrix = []
    status = Counter()
    checked = 0
    for r in trials:
        cue = r['cueStop']
        cells = []
        for cell_id, x, z, old_pocket, old_score in candidates:
            obj = [x, z]
            distance = math.dist(cue, obj)
            options = []
            if distance < 2*g.radius-1e-12:
                reason = 'overlap'
            else:
                for pid, anchor in enumerate(anchors):
                    m = score(cue, obj, anchor, g.radius, pid)
                    check = independent_score(cue, obj, anchor, g.radius)
                    assert (m['score'] is None) == math.isinf(check)
                    if m['score'] is not None:
                        assert math.isclose(m['score'], check, rel_tol=1e-9)
                    options.append(m)
                    checked += 1
                reason = 'available' if any(m['score'] is not None for m in options) else 'no_forward_pocket'
            best = min((m for m in options if m['score'] is not None), key=lambda m: (m['score'], m['pocket']), default=None)
            cells.append(dict(cellID=cell_id, cueObjectDistance=distance, status=reason,
                              best=best, pockets=options))
            status[reason] += 1
        matrix.append(dict(trialID=r['trialID'], comboIndex=r['comboIndex'], cueStop=cue,
                           spinX=r['spinX'], spinY=r['spinY'], velocity=r['velocity'],
                           mainRails=r['cueMainRailsAfterContact'], evaluations=cells))
    summaries = []
    for j, candidate in enumerate(candidates):
        cid, x, z, oldp, olds = candidate
        previous = [score(board['cue'], [x,z], a, g.radius, p) for p,a in enumerate(anchors)]
        oldbest = min((m for m in previous if m['score'] is not None), key=lambda m:(m['score'],m['pocket']), default=None)
        assert (oldbest is None) == (olds is None)
        if oldbest:
            assert oldbest['pocket'] == oldp and math.isclose(oldbest['score'], olds, rel_tol=1e-10)
        finite = [(r['evaluations'][j]['best']['score'], r) for r in matrix if r['evaluations'][j]['best']]
        ordered = sorted(finite, key=lambda t:(t[0],t[1]['comboIndex']))
        scores = [v for v,r in ordered]
        summaries.append(dict(cellID=cid, position=[x,z], originalBest=oldbest,
            availableCount=len(finite), unavailableCount=len(matrix)-len(finite),
            minScore=min(scores) if scores else None, medianScore=float(np.median(scores)) if scores else None,
            maxScore=max(scores) if scores else None,
            bestComboIndex=ordered[0][1]['comboIndex'] if scores else None,
            improvedCount=sum(olds is None or s<olds-1e-12 for s,r in finite),
            bestPocketCounts=dict(Counter(str(r['evaluations'][j]['best']['pocket']) for s,r in finite))))
    assert len(matrix)*len(candidates) == sum(status.values())
    for p, h in source_hashes.items():
        assert digest(ROOT/p) == h
    result = dict(schema='endpoint-second-difficulty-example-v1', layoutID=LID, board=board,
        policy=dict(score='OP / cos(angle(G-C, P-O)); lower is easier',
                    units='metres', pockets='minimum of all six generation anchors, recomputed per endpoint',
                    overlap='center distance < 2R is unavailable',
                    noForward='no pocket with cut < 90 degrees is unavailable',
                    scope='geometric endpoint evaluation only; no second-shot simulation or first-shot B interference replay'),
        sampledAttempts=len(original['rows']), validFirstShots=len(trials), secondCandidates=len(candidates),
        pairCount=len(matrix)*len(candidates), statusCounts=dict(status), checkedPocketScores=checked,
        candidates=summaries, rows=matrix, sourcesSHA256=source_hashes,
        verification='0/45 degree fixtures, independent dot-product scores, original candidate scores, unique combos and source hashes passed')
    (OUT/'analysis.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False))
    fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    values=np.array([[r['evaluations'][j]['best']['score'] if r['evaluations'][j]['best'] else np.nan for r in matrix] for j in range(len(candidates))])
    fig, ax=plt.subplots(figsize=(15,10))
    cmap=plt.get_cmap('YlOrRd').copy();cmap.set_bad('#64748b')
    im=ax.imshow(values,aspect='auto',interpolation='nearest',cmap=cmap,norm=LogNorm(vmin=np.nanmin(values),vmax=np.nanmax(values)))
    ax.set_yticks(range(len(candidates)),[f'B{c[0]}' for c in candidates],fontsize=7)
    ticks=list(range(0,len(matrix),5));ax.set_xticks(ticks,[str(matrix[i]['comboIndex']) for i in ticks],fontsize=9)
    ax.set_xlabel('第一杆组合ID（原630组内的 comboIndex；仅显示95组有效组合）',labelpad=12)
    ax.set_ylabel('第二球候选位置（原网格ID）')
    fig.colorbar(im,ax=ax,label='几何难度 S（米，对数色阶；越浅越容易）',pad=.02)
    fig.suptitle('同一个球形：95个母球停点 × 55个第二球位置',fontsize=20,y=.98)
    fig.text(.08,.925,'每一格重新比较六袋，取最低 S；灰色＝重叠或无正向直击袋。未验证第二球的实际入袋和第一杆干扰。',fontsize=11)
    fig.subplots_adjust(top=.90,bottom=.10,left=.08,right=.93)
    fig.savefig(OUT/'difficulty-matrix.png',dpi=160);plt.close(fig)
    # One fixed B illustrates the variation across all first-shot outcomes.
    chosen=next(c for c in summaries if c['cellID']==43)
    j=next(j for j,c in enumerate(candidates) if c[0]==chosen['cellID'])
    finite=sorted((r for r in matrix if r['evaluations'][j]['best']),key=lambda r:r['evaluations'][j]['best']['score'])
    examples=[]
    for r in [finite[0],finite[len(finite)//2],finite[-1]]:
        examples.append(dict(comboIndex=r['comboIndex'],cueStop=r['cueStop'],mainRails=r['mainRails'],**r['evaluations'][j]))
    (OUT/'example.json').write_text(json.dumps(dict(candidate=chosen,examples=examples),ensure_ascii=False,indent=2))
    text=f'''# 单球形：第一杆组合 × 第二球候选位置\n\n球形 `{LID}`，原切角17°。100次尝试中95次第一杆有效；55个保留候选，形成95×55=5,225格。\n\n每行是一组第一杆参数及实测母球停点，每列是一个固定第二球位置；每格保存六袋的切角、目标球到生成下球点距离、S=OP/cos(cut)，以及几何最低分袋口。同时保存母球到第二球距离，但沿用旧分数，该距离不作为独立乘项。无正向袋或球重叠时保留不可用标记，不填0、不丢行。\n\n汇总按第二球位置输出可评分数、不可用数、有限分数的最小/中位/最大值、最佳第一杆组合及各最佳袋出现次数。未定义简单/中等/困难阈值。组合覆盖率不是进球概率，也不是击球扰动下的稳定性。\n\n这一轮只做一个球形。第一球已入袋，不作为第二杆障碍；55个候选各自独立，不是同时摆55球。六袋评估沿用几何生成下球点，不构成模拟器进袋确认。第一杆模拟时未加入第二球，实际途中碰撞可能使母球终点改变；需另行复验。\n\n- [完整表与六袋明细](analysis.json)\n- [固定B43的三组对比](example.json)\n- [难度矩阵图](difficulty-matrix.png)\n\n验证：0°/45°标准夹具、所有计算分数与独立点积公式一致、原候选分数重现、组合ID唯一、源文件哈希未变。\n'''
    (OUT/'README.md').write_text(text)
    print(json.dumps({k:result[k] for k in ['validFirstShots','secondCandidates','pairCount','statusCounts','checkedPocketScores']},ensure_ascii=False))
    print(json.dumps(dict(candidate=chosen,examples=examples),ensure_ascii=False))


if __name__ == '__main__':
    main()

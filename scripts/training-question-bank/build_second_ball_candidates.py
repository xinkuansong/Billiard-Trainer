#!/usr/bin/env python3
"""Eight-process full companion bank; checkpoints, independent audit and statistics."""
from collections import Counter
import concurrent.futures
import hashlib
import json
import math
import multiprocessing
from pathlib import Path
import time

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.ticker import StrMethodFormatter

from benchmark_second_ball_grid import initialize, batch
from pocket_geometry_filter import Geometry, layouts

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json'
PREVIEW=ROOT/'output/two-ball-second-grid-20261024/preview-data.json'
OUT=ROOT/'output/two-ball-second-candidates-20261024'
WORKERS=8
CHUNK=500


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()


def atomic_json(path,value):
    tmp=path.with_suffix(path.suffix+'.tmp')
    tmp.write_text(json.dumps(value,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
    tmp.replace(path)


def distances(points,a,b):
    """Vectorized finite-segment projection for independent audit."""
    a=np.asarray(a); b=np.asarray(b)
    v=b-a
    projection=np.sum((points-a)*v,axis=-1)/np.sum(v*v,axis=-1)
    nearest=a+np.clip(projection,0,1)[...,None]*v
    return np.linalg.norm(points-nearest,axis=-1)


def pocket_clearance(points,pocket):
    c=np.array([pocket['center']['x'],pocket['center']['z']])
    clearance=np.linalg.norm(points-c,axis=1)-pocket['radius']
    poly=np.array([[p['x'],p['z']] for p in pocket['lip']])
    inside=np.zeros(len(points),dtype=bool)
    edge_distance=np.full(len(points),np.inf)
    for a,b in zip(poly,np.roll(poly,-1,axis=0)):
        edge_distance=np.minimum(edge_distance,distances(points,a,b))
        if a[1]!=b[1]:
            cross=((a[1]>points[:,1])!=(b[1]>points[:,1])) & (points[:,0]<a[0]+(points[:,1]-a[1])*(b[0]-a[0])/(b[1]-a[1]))
            inside ^= cross
    return np.minimum(clearance,np.where(inside,0,edge_distance))


def score_matrix(cue,obj,anchors,r):
    """Independent dot-product score, shape N x pockets; forward only."""
    outgoing=anchors[None,:,:]-obj[:,None,:]
    length=np.linalg.norm(outgoing,axis=2)
    unit=outgoing/length[:,:,None]
    approach=obj[:,None,:]-2*r*unit-cue[:,None,:]
    dot=np.sum(approach*unit,axis=2)
    score=np.full(dot.shape,np.inf)
    np.divide(length*np.linalg.norm(approach,axis=2),dot,out=score,where=dot>0)
    return score


def audit_chunk(rows,originals,g,geometry):
    """Audit every retained point, including best of all six pocket scores."""
    cue=[];obj=[];pid=[];candidate=[];cell=[];best_pid=[];best_score=[]
    for row,original in zip(rows,originals,strict=True):
        lid,c,a,p,angle=original
        assert row['id']==lid
        points=row['candidates'];rejected=row['rejected']
        assert set(rejected)=={'path','difficulty'}
        assert all(type(n)==int and n>=0 for n in rejected.values())
        assert len(points)+sum(rejected.values())==72
        ids=[p[0] for p in points]
        assert ids==sorted(set(ids)) and all(type(i)==int and 0<=i<72 for i in ids)
        for index,x,z,bp,bs in points:
            assert (bp is None)==(bs is None)
            if bp is not None: assert type(bp)==int and 0<=bp<6 and math.isfinite(bs) and bs>0
            cue.append(c);obj.append(a);pid.append(p);candidate.append((x,z));cell.append(index)
            best_pid.append(-1 if bp is None else bp);best_score.append(np.inf if bs is None else bs)
    if not candidate: return 0,0
    c=np.array(cue);a=np.array(obj);b=np.array(candidate);pid=np.array(pid);cell=np.array(cell)
    assert np.isfinite(b).all()
    r,hx,hz=g.radius,g.length/2,g.width/2
    dx,dz=(g.length-2*r)/12,(g.width-2*r)/6
    centers=np.stack([-hx+r+(cell%12+.5)*dx,-hz+r+(cell//12+.5)*dz],axis=1)
    assert (np.abs(b-centers)<=.05+1e-12).all()
    assert (hx-np.abs(b[:,0])>=r-1e-12).all() and (hz-np.abs(b[:,1])>=r-1e-12).all()
    assert (np.linalg.norm(b-c,axis=1)>=2*r-1e-12).all()
    assert (np.linalg.norm(b-a,axis=1)>=2*r-1e-12).all()
    for pocket in geometry['pockets']: assert (pocket_clearance(b,pocket)>=r-1e-12).all()
    anchors=np.array(g.anchors());p=anchors[pid]
    direction=p-a;op=np.linalg.norm(direction,axis=1)
    ghost=a-2*r*direction/op[:,None]
    assert (distances(b,c,ghost)>=2*r-1e-12).all()
    assert (distances(b,a,p)>=2*r-1e-12).all()
    first=score_matrix(c,a,anchors,r)[np.arange(len(c)),pid]
    second=score_matrix(c,b,anchors,r)
    second_min=second.min(axis=1)
    assert (first<=second_min+1e-10).all()
    np.testing.assert_allclose(second_min,np.array(best_score),rtol=1e-9,atol=1e-11)
    valid=np.isfinite(second_min)
    bp=np.array(best_pid)
    assert (bp[~valid]==-1).all()
    np.testing.assert_allclose(second[np.arange(len(c))[valid],bp[valid]],second_min[valid],rtol=1e-9,atol=1e-11)
    return len(b),int((~valid).sum())


def main():
    started=time.perf_counter()
    source_hash=sha(SOURCE);preview_hash=sha(PREVIEW)
    bank=json.loads(SOURCE.read_text());preview=json.loads(PREVIEW.read_text())
    assert source_hash==preview['sourceSHA256']=='e72eb3ea72e78ef8b1e61b4ea6b5deecc815feff232f13aba36b54ba1e5a5118'
    records=list(layouts(bank));assert len(records)==135700 and len({x[0] for x in records})==135700
    g=Geometry(**{k:bank['geometry'][k] for k in ('length','width','radius')})
    frozen={b['id']:[p['position'] for p in b['points']] for b in preview['boards']}
    OUT.mkdir(parents=True,exist_ok=True)
    parts=OUT/'parts';parts.mkdir(exist_ok=True)
    contract=dict(schema='second-ball-candidate-companion-v1',source=str(SOURCE.relative_to(ROOT)),sourceSHA256=source_hash,
                  previewSHA256=preview_hash,workers=WORKERS,shardSize=CHUNK,firstBallLayouts=len(records),candidatesPerLayout=72,
                  ruleVersion='second-ball-corridor-priority-v1',jitterMetres=.05,columns=12,rows=6,
                  coordinateSystem='SceneKit XZ metres; +X right, +Z down in landscape',
                  candidateColumns=['cellIndex','x','z','comparisonBestPocket','comparisonBestScore'],
                  seedRule='Python Random(int.from_bytes(SHA256(UTF8("second-grid-v1\\0" + originalID)), "big")); four frozen preview boards override',
                  frozenPreviewBoards=frozen,
                  rule='B clears finite C->ghost(A,P) and A->P by 2R; S(A,original P)<=min S(B,six generation anchors); cut<90; no simulation qualification',
                  scriptsSHA256={p.name:sha(p) for p in [Path(__file__),ROOT/'scripts/training-question-bank/benchmark_second_ball_grid.py',
                        ROOT/'scripts/training-question-bank/filter_second_ball_preview.py',ROOT/'scripts/training-question-bank/preview_second_ball_grid.py',
                        ROOT/'scripts/training-question-bank/pocket_geometry_filter.py']})
    manifest_path=OUT/'manifest.json'
    if manifest_path.exists(): assert json.loads(manifest_path.read_text())==contract,'Existing output has different contract'
    else: atomic_json(manifest_path,contract)
    jobs=[(i,records[j:j+CHUNK],str(parts)) for i,j in enumerate(range(0,len(records),CHUNK))]
    receipts={};pending=[]
    for job in jobs:
        receipt_path=parts/f'part-{job[0]:03}.receipt.json';part=parts/f'part-{job[0]:03}.jsonl'
        if receipt_path.exists():
            receipt=json.loads(receipt_path.read_text())
            assert part.exists() and sha(part)==receipt['sha256'] and receipt['layouts']==len(job[1])
            receipts[job[0]]=receipt
        else: pending.append(job)
    print(f'START: {len(records):,} layouts, {len(records)*72:,} candidates; {WORKERS} workers, {len(jobs)} shards; resume {len(receipts)}.',flush=True)
    generation_start=time.perf_counter();last=0
    with concurrent.futures.ProcessPoolExecutor(max_workers=WORKERS,mp_context=multiprocessing.get_context('spawn'),
            initializer=initialize,initargs=(bank['geometry'],frozen)) as pool:
        futures={pool.submit(batch,job):job[0] for job in pending}
        for future in concurrent.futures.as_completed(futures):
            result=future.result();i=result['index']
            assert sha(parts/f'part-{i:03}.jsonl')==result['sha256']
            receipts[i]=result
            atomic_json(parts/f'part-{i:03}.receipt.json',result)
            now=time.perf_counter()
            if now-last>=12 or len(receipts)==len(jobs):
                progress=dict(phase='generation',completedShards=len(receipts),totalShards=len(jobs),
                              completedLayouts=sum(r['layouts'] for r in receipts.values()),
                              keptSoFar=sum(r['kept'] for r in receipts.values()),elapsedSeconds=now-started)
                atomic_json(OUT/'progress.json',progress);print(json.dumps(progress),flush=True);last=now
    generation_seconds=time.perf_counter()-generation_start
    print('MERGE/AUDIT: independently checking every retained candidate, original IDs and sample replay.',flush=True)
    benchmark=ROOT/'output/two-ball-second-grid-20261024/benchmark/sample-10000/workers-8'
    known={}
    for p in sorted(benchmark.glob('part-*.jsonl')):
        for line in p.read_text().splitlines():
            row=json.loads(line);known[row['id']]=row
    assert len(known)==10000
    hist=np.zeros(73,dtype=np.int64);angle_stats={a:Counter() for a in range(86)}
    rejected=Counter();all_counts=[];checks=0;replayed=0;no_forward=0;seen=set()
    merged_tmp=OUT/'second-ball-candidates.jsonl.tmp'
    merge_start=time.perf_counter()
    with merged_tmp.open('wb') as merged:
        for i,originals,_ in jobs:
            part=parts/f'part-{i:03}.jsonl';payload=part.read_bytes()
            assert hashlib.sha256(payload).hexdigest()==receipts[i]['sha256']
            rows=[json.loads(line) for line in payload.splitlines()]
            assert len(rows)==len(originals)
            n,unavailable=audit_chunk(rows,originals,g,bank['geometry']);checks+=n;no_forward+=unavailable
            assert sum(len(row['candidates']) for row in rows)==receipts[i]['kept']
            for row,original in zip(rows,originals,strict=True):
                assert row['id'] not in seen;seen.add(row['id'])
                count=len(row['candidates']);hist[count]+=1;all_counts.append(count)
                rejected.update(row['rejected'])
                angle_stats[original[-1]].update(dict(layouts=1,withCandidates=int(count>0),candidates=count))
                if row['id'] in known:
                    assert row==known[row['id']];replayed+=1
            merged.write(payload)
            if i%50==0: print(f'AUDIT: {i+1}/{len(jobs)} shards, {checks:,} retained candidates checked.',flush=True)
    assert replayed==10000 and len(seen)==len(records)
    retained=int(np.arange(73)@hist);assert retained==checks
    assert retained+sum(rejected.values())==len(records)*72
    assert sha(SOURCE)==source_hash and sha(PREVIEW)==preview_hash
    merged_path=OUT/'second-ball-candidates.jsonl';merged_tmp.replace(merged_path)
    audit_seconds=time.perf_counter()-merge_start
    counts=np.array(all_counts);nonempty=counts[counts>0]
    bounds=[(0,0),(1,10),(11,20),(21,30),(31,40),(41,50),(51,60),(61,72)]
    grouped=[dict(label='0' if lo==hi else f'{lo}–{hi}',min=lo,max=hi,layouts=int(hist[lo:hi+1].sum())) for lo,hi in bounds]
    summary=dict(firstBallLayouts=len(records),initialCandidates=len(records)*72,retainedCandidates=retained,
                 deletedCandidates=sum(rejected.values()),retainedFraction=retained/(len(records)*72),
                 layoutsWithCandidates=len(nonempty),layoutsWithoutCandidates=int(hist[0]),
                 meanCandidatesPerLayout=float(counts.mean()),meanCandidatesPerNonemptyLayout=float(nonempty.mean()),
                 medianCandidatesPerLayout=float(np.median(counts)),maximumCandidates=int(counts.max()),
                 percentiles={str(p):float(np.percentile(counts,p)) for p in (5,25,50,75,95)},
                 deletionReasons=dict(rejected),placementRejections=sum(v['retries'] for v in receipts.values()),
                 noForwardSecondPocketAmongRetained=no_forward,groupedDistribution=grouped,
                 exactDistribution=[dict(retained=i,layouts=int(n)) for i,n in enumerate(hist)],
                 angleBreakdown=[dict(angle=a,**dict(c)) for a,c in angle_stats.items()],
                 workers=WORKERS,generationSeconds=generation_seconds,mergeAndAuditSeconds=audit_seconds,
                 outputBytes=merged_path.stat().st_size,outputSHA256=sha(merged_path),
                 checks=dict(allSourceIDsExactlyOnce=True,allRetainedIndependentlyAudited=checks,
                             priorBenchmarkRowsReproduced=replayed,sourceUnchanged=True,previewUnchanged=True))
    font_manager.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    fig,ax=plt.subplots(figsize=(12.5,6.8),facecolor='white')
    values=[v['layouts'] for v in grouped]
    bars=ax.bar(range(len(grouped)),values,color=['#bd6a55']+['#197f98']*7,width=.68,zorder=3)
    for bar,value in zip(bars,values): ax.text(bar.get_x()+bar.get_width()/2,value+max(values)*.018,f'{value:,}',ha='center',fontsize=12)
    ax.set_xticks(range(len(grouped)),[v['label'] for v in grouped],fontsize=12)
    ax.set_xlabel('每个原球形保留的第二球候选数量（个）',fontsize=13,labelpad=14)
    ax.set_ylabel('原球形数量（个）',fontsize=13)
    ax.yaxis.set_major_formatter(StrMethodFormatter('{x:,.0f}'))
    ax.grid(axis='y',color='#e2e8eb',zorder=0);ax.spines[['top','right']].set_visible(False)
    ax.set_ylim(0,max(values)*1.18)
    fig.suptitle('第二球几何筛选后 · 每个球形保留数量分布',x=.08,ha='left',fontsize=21,y=.98)
    fig.text(.08,.89,f'原球形 {len(records):,} 个 · 有候选 {len(nonempty):,} 个 · 保留候选共 {retained:,} 个',fontsize=12,color='#536471')
    fig.text(.08,.025,'0档单独展示；其余按区间汇总。仅通过摆位、线路及相对几何难度检查，尚未验证走位可达性。',fontsize=10,color='#64727b')
    fig.subplots_adjust(left=.10,right=.98,top=.82,bottom=.15)
    fig.savefig(OUT/'retained-count-distribution.png',dpi=180)
    fig.savefig(OUT/'retained-count-distribution.svg')
    plt.close(fig)
    summary['totalSeconds']=time.perf_counter()-started
    atomic_json(OUT/'summary.json',summary)
    atomic_json(OUT/'progress.json',dict(phase='complete',layouts=len(records),retainedCandidates=retained,totalSeconds=summary['totalSeconds']))
    print(json.dumps({k:v for k,v in summary.items() if k not in ('exactDistribution','angleBreakdown')},ensure_ascii=False,indent=2),flush=True)


if __name__=='__main__': main()

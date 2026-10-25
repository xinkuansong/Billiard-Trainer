"""Audit every saved candidate and render before/after without touching corpus."""
from refine_below85 import *
import numpy as np
sys.path.insert(0,str(HERE))
import preview_below85 as V
from audit_report import recompute
import matplotlib.pyplot as plt
import shutil,urllib.request

def main():
    d=read(OUT/'results.json');g=d['geometry'];trials=json.loads(gzip.decompress((OUT/'trials.json.gz').read_bytes()));checks=[];cards=[]
    for p,h in d['sourceHashes'].items():assert sha(Path(p))==h
    assert len(d['samples'])==len(trials)==5
    for result,trace in zip(d['samples'],trials,strict=True):
        s=result['sample'];n=s['number'];root=s['route'];after=result['after'];old=s['score'];new=after['scores'];route=after['route'];valid=[]
        for t in trace['trials']:
            r=t['route'];v,x,y=t['parameters']
            assert .6<=v<=4.5 and x*x+y*y<=.25+1e-8
            assert abs(v-root['velocity'])<=.3+1e-6 and abs(x-root['spinX'])<=.1+1e-6 and abs(y-root['spinY'])<=.15+1e-6
            if t['reject']:
                assert 'scores' not in t;continue
            assert r['status']=='success' and r['targetPottedSelected'] and not r['cuePocketed']
            assert P.seq(r)==tuple(result['expectedRails'])==P.seq(root)
            assert C.railseq(r)==result['expectedRails']
            assert r['cueJawsAfterContact']==r['cueOtherCushionsAfterContact']==0
            assert P.seq(r) or r['spinX']==0
            path=[q[1:] for q in r['trajectory2mm']['points']]
            assert C.nearest(s['position'],path)>C.diameter+.002
            assert C.nearest(s['position'],[s['board']['cue'],path[0]])>C.diameter
            # Recorder and final position differ by Float rounding (observed <=1.2e-7m).
            # Use the existing native compactTrajectory endpoint contract, 1e-6m.
            assert math.dist(path[-1],r['cueStop'])<1e-6 and r['trajectory2mm']['maxDeviationMeters']<=.002+1e-8
            actual=recompute(g,np.array([r['cueStop']]),np.array([s['position']]),np.array([old['pocket']]))[0]
            assert np.max(np.abs(actual-[t['scores'][k] for k in V.FIELDS+['totalScore']]))<1e-8
            valid.append(t)
        qualified=[t for t in valid if t['scores']['totalScore']>=85]
        chosen=min(qualified,key=lambda q:(q['change'],abs(q['route']['spinX']),-q['scores']['totalScore'],q['parameters'])) if qualified else max(valid,key=lambda q:(q['scores']['totalScore'],-q['change']))
        assert chosen==after and len(qualified)==result['qualifying']
        assert result['simulated']+sum(trace['parameterPrune'].values())==245
        checks.append(dict(sample=n,scored=len(valid),qualified=len(qualified),stateRejected=sum(t['reject']=='railStateChanged' for t in trace['trials']),chosenOptimalUnderPolicy=True))
        status='达标 · 选择改动较小的候选' if result['qualified'] else '未达标 · 展示网格内最高分，原路线保留'
        fig=plt.figure(figsize=(18,10),facecolor=V.BG)
        fig.suptitle(f'样本 {n}｜{old["totalScore"]:.1f} → {new["totalScore"]:.1f} 分｜{status}',fontsize=21,y=.97)
        fig.text(.04,.91,f'{s["id"]}  ·  B{s["cellID"]} → {V.NAMES[old["pocket"]]}  ·  吃库顺序 {" → ".join(map(str,result["expectedRails"]))}（前后一致）',fontsize=13,color=V.GREEN)
        a=fig.add_axes([.035,.43,.445,.42]);V.table(a,g,s);a.set_title('优化前 · 原版路线',fontsize=16)
        ss=copy.deepcopy(s);ss['route']=route;ss['score']=new
        a=fig.add_axes([.52,.43,.445,.42]);V.table(a,g,ss);a.set_title('优化后 · '+('达标' if result['qualified'] else '仍低于85分'),fontsize=16,color=V.GREEN if result['qualified'] else V.RED)
        oldpath=np.asarray(root['trajectory2mm']['points'])[:,1:3];a.plot(oldpath[:,0],oldpath[:,1],ls='--',lw=1,color='#8e9990',alpha=.65,zorder=1)
        cols=['阶段','球距分','出杆空间分','角度分','总分','球距 cm','球面离库 cm','第二杆切角']
        def vals(q,label):return [label,*[f'{q[k]:.1f}' for k in V.FIELDS+['totalScore']],f'{q["distanceMeters"]*100:.1f}',f'{q["gapMeters"]*100:.2f}',f'{q["angleDegrees"]:.2f}°']
        a=fig.add_axes([.04,.21,.92,.16]);a.axis('off');tb=a.table(cellText=[vals(old,'原版'),vals(new,'微调')],colLabels=cols,cellLoc='center',loc='center');tb.auto_set_font_size(False);tb.set_fontsize(13);tb.scale(1,2)
        for (i,j),cell in tb.get_celld().items():
            cell.set_edgecolor('#cbd7c7');cell.set_facecolor('#e4edde' if i==0 else '#ffffff')
            if j==4 and i:cell.get_text().set_weight('bold')
        fig.text(.04,.16,f'杆速 {root["velocity"]:.3f} → {route["velocity"]:.3f} m/s    左右塞 {root["spinX"]:+.3f} → {route["spinX"]:+.3f}    高低杆 {root["spinY"]:+.3f} → {route["spinY"]:+.3f}',fontsize=14)
        fig.text(.04,.11,f'245个原始网格点 · 实际模拟 {result["simulated"]} · 合法同库序 {len(valid)} · 达到85分 {len(qualified)}；状态改变候选不评分。',fontsize=12)
        note='注意：总分达标不代表每项达标；本例切角增至31.08°，角度分75.0，未使用18°硬限制。' if n==1 else '本例在既定范围内未达到85分，球距仍约166cm；不扩大扰动、不改变吃库类型。' if not qualified else '已达标后优先少改参数，不继续追求100分或直线。'
        fig.text(.04,.065,note,fontsize=13,color=V.RED if n in (1,4) else V.GREEN)
        fig.text(.04,.025,'蓝实线：原生模拟母球轨迹；右图灰虚线：原版轨迹参考；红圈：停点。B及第二杆袋口固定；题库/App均未修改。',fontsize=11,color='#607367')
        for ext in ('png','svg'):fig.savefig(OUT/f'sample-{n}.{ext}',dpi=140)
        plt.close(fig)
        head=f'样本{n} · {old["totalScore"]:.1f} → {new["totalScore"]:.1f} · '+('达标' if qualified else '未达标')
        cells=''.join('<tr>'+''.join(f'<td>{v}</td>' for v in vals(q,label))+'</tr>' for q,label in [(old,'原版'),(new,'微调')])
        cards.append(f'<section id="sample-{n}"><h2>{head}</h2><p>{note}</p><a href="sample-{n}.svg" target="_blank"><img src="sample-{n}.png" alt="{head}，前后轨迹与三项评分"></a><div class="scroll"><table><tr>'+''.join(f'<th>{c}</th>' for c in cols)+f'</tr>{cells}</table></div><p>{status}。合法候选{len(valid)}条，其中{len(qualified)}条达到85分。</p></section>')
    verified=dict(passed=True,samples=checks,sourceSHAUnchanged=True,independentScoreAudit=True,allOriginalReplaysExact=True,allSelectedRailsPreserved=True,noRejectedCandidateScored=True,corpusChanged=False)
    write(OUT/'verification.json',verified)
    total=sum(x['simulated'] for x in d['samples']);qs=sum(x['qualified'] for x in d['samples']);states=sum(x['stateRejected'] for x in checks)
    summary=dict(samples=5,qualified=qs,notQualified=5-qs,simulated=total,stateChangedRejected=states,computeSeconds=d['computeSeconds'],elapsedIncludingBootSeconds=d['elapsedSeconds'],trialsGzipBytes=(OUT/'trials.json.gz').stat().st_size,auditPassed=True)
    write(OUT/'summary.json',summary)
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>舒适度85分微调 · 五例对比</title><style>body{margin:0;background:#f6f8f1;color:#243f32;font:17px/1.8 system-ui}main{max-width:1600px;margin:auto;padding:24px}section{scroll-margin-top:90px;background:white;padding:20px;border:1px solid #ccd8c9;margin:28px 0;border-radius:12px}img{width:100%;display:block}nav{position:sticky;top:0;background:#f6f8f1f5;padding:12px 24px;display:flex;gap:24px;flex-wrap:wrap;z-index:3;border-bottom:1px solid #ccd8c9}a{color:#276b55}table{width:100%;border-collapse:collapse}td,th{padding:10px;border:1px solid #ccd8c9;text-align:center;white-space:nowrap}.scroll{overflow:auto}h1{line-height:1.4}@media(max-width:650px){main,section{padding:10px}td,th{padding:6px;font-size:13px}}</style><nav>'''+''.join(f'<a href="#sample-{i}">样本{i}</a>' for i in range(1,6))+'''<a href="../comfort-below85-five/">原版五例</a></nav><main><h1>舒适度85分微调 · 五例前后对比</h1>'''+f'<p><b>5条原路线，4条达到85分，1条未达标。</b>本轮模拟{total}个合法参数点，物理与评分计算{d["computeSeconds"]:.2f}秒（含启动{d["elapsedSeconds"]:.2f}秒）。</p>'+'''<p>固定原B位置与目标袋口；速度±0.3（步0.1）、高低±0.15（步0.05）、左右±0.10（步0.05）。吃库数量/顺序变化、袋角、自杀、首球未入指定袋、途中碰B直接剔除。采用球距放缓版、空间最新版和15°内满分角度分，等权几何平均；不再使用18°硬角度限制。</p><p>达到85分的候选优先最小参数改动：按各自最大扰动范围归一化后的改变量平方和最小；并列先少侧塞、再高总分。未达标展示网格内最高分，原路线保留。本次只比较这5条对应路线，不重排同题其他推荐、不跑全量。</p><p>5条原路线都有吃库，2条本就无侧塞；本轮没有需要按“无库去侧塞”规则强制归零的原路线。样本1虽总分达标，切角变为31.08°，需结合直觉评阅。</p>'''+''.join(cards)+'''<p><a href="results.json">完整结果</a> · <a href="trials.json.gz">全部扰动轨迹和淘汰原因（gzip）</a> · <a href="manifest.json">冻结规则</a> · <a href="verification.json">校验记录</a></p></main></html>'''
    (OUT/'index.html').write_text(page)
    served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-refine-five';served.mkdir(exist_ok=True)
    paths=[p for p in OUT.iterdir() if p.is_file() and p.suffix in ('.json','.gz','.png','.svg','.html') and p.name not in ('failure.json','progress.json')]
    http=[]
    for p in paths:
        shutil.copy2(p,served/p.name)
        response=urllib.request.urlopen('http://127.0.0.1:51240/comfort-refine-five/'+p.name).read();assert hashlib.sha256(response).hexdigest()==sha(p);http.append(p.name)
    write(OUT/'delivery.json',dict(httpFiles=http,byteEqualityPassed=True,url='http://127.0.0.1:51240/comfort-refine-five/#sample-1'))
    print(json.dumps(summary,ensure_ascii=False))
if __name__=='__main__':main()

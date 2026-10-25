"""Fixed B43 exclusion against swept, recorded first-shot paths; unchanged scores."""
from pathlib import Path
import json, math, hashlib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/two-ball-second-difficulty-20261024'

def closest_segment(p,a,b):
    v=[b[i]-a[i] for i in range(2)]; vv=sum(x*x for x in v)
    u=max(0.,min(1.,sum((p[i]-a[i])*v[i] for i in range(2))/vv)) if vv else 0.
    q=[a[i]+u*v[i] for i in range(2)]
    return math.dist(p,q),u,q

def closest_path(p,path):
    assert len(path)>1
    result=[]
    for a,b in zip(path,path[1:]):
        dist,u,q=closest_segment(p,a[1:],b[1:])
        result.append(dict(distance=dist,time=a[0]+u*(b[0]-a[0]),point=q))
    return min(result,key=lambda x:x['distance'])

def main():
    # Interior crossing, endpoint clamping, degenerate segment and exact tangency.
    assert closest_segment([0,0],[-1,0],[1,0])[0]==0
    assert closest_segment([2,0],[0,0],[1,0])[0]==1
    assert closest_segment([0,1],[0,0],[0,0])[0]==1
    assert closest_segment([0,1],[-1,0],[1,0])[0]==1
    source=OUT/'b43-ranked.json';prior=json.loads(source.read_text())
    replay=json.loads((OUT/'b43-all95-trajectories.json').read_text())
    radius=json.loads((ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json').read_text())['geometry']['radius']
    diameter=2*radius;B=prior['position'];lookup={r['comboIndex']:r for r in replay['rows']}
    assert len(lookup)==95 and set(lookup)=={r['comboIndex'] for r in prior['rows']}
    kept=[];removed=[]
    for old in prior['rows']:
        trial=lookup[old['comboIndex']]
        cue=closest_path(B,trial['paths']['cueBall'])
        capture=next(e['time'] for e in trial['events'] if e['kind']=='pocket' and e['ball']=='object')
        obj=closest_path(B,[pt for pt in trial['paths']['object'] if pt[0]<=capture])
        checks=dict(cue=cue,object=obj)
        # Downsampled comparison provides an empirical interpolation sensitivity check.
        coarse=closest_path(B,trial['paths']['cueBall'][::2]+[trial['paths']['cueBall'][-1]])
        checks['cueCoarseDifference']=abs(coarse['distance']-cue['distance'])
        hit=[name for name in ['cue','object'] if checks[name]['distance']<=diameter]
        row=dict(old,oldRank=old.get('rank'),rank=None,pathChecks=checks,collisionBalls=hit)
        if hit or old['status']!='available':removed.append(row)
        else:kept.append(row)
    kept.sort(key=lambda q:(q['best']['score'],q['comboIndex']))
    for i,q in enumerate(kept,1):q['rank']=i
    # No score alteration and every original combination accounted for once.
    assert len(kept)+len(removed)==95
    assert all(q['pathChecks'][name]['distance']>diameter for q in kept for name in ['cue','object'])
    assert all(q['best']==next(r['best'] for r in prior['rows'] if r['comboIndex']==q['comboIndex']) for q in kept)
    result=dict(layoutID=prior['layoutID'],position=B,radius=radius,diameter=diameter,
        method='minimum point-to-segment distance over complete native replay paths (120Hz plus all event/frame timestamps); remove at <=2R; first object checked until pocket capture',
        scope='Recorded X-Z swept path screening against fixed B43; no three-ball re-simulation or second-shot pot verification',
        total=95,keptCount=len(kept),removedCount=len(removed),rows=kept,removed=removed,
        sourceSHA256=hashlib.sha256(source.read_bytes()).hexdigest(),
        minimumBoundaryMargin=min(abs(q['pathChecks'][n]['distance']-diameter) for q in kept+removed for n in ['cue','object']),
        maximumCoarseDifference=max(q['pathChecks']['cueCoarseDifference'] for q in kept+removed))
    (OUT/'b43-path-filtered-ranked.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False))
    names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
    lines=['# B43：剔除途中碰球后的难度排序','',f'95个原有效组合，保留{len(kept)}个，剔除{len(removed)}个。直径阈值{diameter*100:.3f}厘米；整条母球路径与第一球入袋前路径均检查。','',
        '采用原模拟轨迹逐段扫掠检测，包含起点、运动中和停点；不是仅检查离散点。相切也剔除。难度公式、袋口选择、打点和杆速均不变。旧排名与旧数据保留。', '',
        '这是原轨迹的几何碰撞筛选，未把B43加入三球模拟；第二杆入袋仍未模拟验证。','',
        '|新排名|旧排名|组合|难度S（米）|第二杆袋口|切角|母球路径最小球心距（cm）|吃库|','|---:|---:|---:|---:|---|---:|---:|---:|']
    for q in kept:
        lines.append(f"|{q['rank']}|{q['oldRank']}|{q['comboIndex']}|{q['best']['score']:.6f}|{names[q['best']['pocket']]}|{q['best']['angle']:.2f}°|{q['pathChecks']['cue']['distance']*100:.3f}|{q['firstShotMainRails']}|")
    lines+=['','## 删除项','','|原排名|组合|最小母球球心距（cm）|距最近处时间（s）|原因|','|---:|---:|---:|---:|---|']
    for q in sorted(removed,key=lambda x:x.get('oldRank') or 999):
        reason='母球途中或停点碰B43' if 'cue' in q['collisionBalls'] else '第一球途中碰B43' if 'object' in q['collisionBalls'] else q['status']
        lines.append(f"|{q['oldRank'] or '不可评分'}|{q['comboIndex']}|{q['pathChecks']['cue']['distance']*100:.3f}|{q['pathChecks']['cue']['time']:.4f}|{reason}|")
    lines+=['',f"检查：点到线段标准夹具、95组ID完整、原字段重跑一致、保留项全程球心距>2R、原评分不变均通过。距碰撞阈值最近的样本余量为{result['minimumBoundaryMargin']*1000:.3f}mm；二倍步长对照最大距离差{result['maximumCoarseDifference']*1000:.4f}mm（此项为经验敏感性检查，不是误差上界证明）。"]
    (OUT/'b43-path-filtered-ranking.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['rows','removed']},ensure_ascii=False))
    print('REMOVED',[(q['comboIndex'],q['oldRank'],q['pathChecks']['cue']['distance']) for q in removed])
    print('TOP10',[(q['rank'],q['comboIndex'],q['oldRank'],q['best']['score']) for q in kept[:10]])
if __name__=='__main__':main()

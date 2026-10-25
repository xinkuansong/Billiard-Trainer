#!/usr/bin/env python3
"""Geometry screening uses production effective pocket aims; physics is Swift-only."""
from pathlib import Path
import json,math,sys,collections,csv,html
import numpy as np
OUT=Path(__file__).resolve().parent
def read(name):return json.loads((OUT/name).read_text())
def save(name,value): (OUT/name).write_text(json.dumps(value,ensure_ascii=False,separators=(',',':')))
def corridor(points,path):
    p=np.asarray(path,dtype=float)
    if len(p)==0:return np.full(len(points),np.inf)
    if len(p)==1:return np.linalg.norm(points-p[0],axis=1)
    a=p[:-1];v=np.diff(p,axis=0);ll=np.maximum(np.sum(v*v,axis=1),1e-20);d=np.full(len(points),np.inf)
    for j in range(0,len(a),128):
        q=points[:,None,:]-a[None,j:j+128,:];w=v[None,j:j+128,:]
        t=np.clip(np.sum(q*w,axis=2)/ll[None,j:j+128],0,1)
        d=np.minimum(d,np.linalg.norm(q-t[:,:,None]*w,axis=2).min(axis=1))
    return d
def angle_values(stop,points,aims,radius):
    n=aims-points;n/=np.linalg.norm(n,axis=1)[:,None]
    ghost=points-2*radius*n;inc=ghost-stop
    inc/=np.maximum(np.linalg.norm(inc,axis=1)[:,None],1e-20)
    return np.degrees(np.arctan2(n[:,0]*inc[:,1]-n[:,1]*inc[:,0],np.sum(n*inc,axis=1)))
def geometry_checks():
    pts=np.array([[0.,0.]])
    assert abs(angle_values(np.array([-1.,0]),pts,np.array([[1.,0]]),.028575)[0])<1e-8
    ghost=np.array([-.05715,0.]);cue=ghost-np.array([1.,1.])
    assert abs(angle_values(cue,pts,np.array([[1.,0]]),.028575)[0]-45)<1e-8
    assert np.allclose(corridor(np.array([[2.,1.],[.5,1.]]),[[0,0],[1,0]]),[math.sqrt(2),1])
    assert np.allclose(corridor(np.array([[-2.,1.],[-.5,1.]]),[[0,0],[-1,0]]),[math.sqrt(2),1])
def shape(ids,points):
    ids=set(ids)
    if not ids:return {'count':0,'gridAreaM2':0,'largestComponent':0,'interiorRadiusEstimate':0,'bestIndex':None}
    remaining=set(ids);sizes=[]
    while remaining:
        stack=[remaining.pop()];count=0
        while stack:
            i=stack.pop();count+=1;x,z=divmod(i,41)
            for xx,zz in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
                k=xx*41+zz
                if 0<=xx<=80 and 0<=zz<=40 and k in remaining:remaining.remove(k);stack.append(k)
        sizes.append(count)
    yes=sorted(ids);no=sorted(set(range(len(points)))-ids)
    distances=np.linalg.norm(points[yes,None,:]-points[None,no,:],axis=2).min(axis=1)
    # Finite grid estimate only, not a certified continuous disk.
    j=int(distances.argmax());return {'count':len(ids),'gridAreaM2':len(ids)*.03**2,'largestComponent':max(sizes),'interiorRadiusEstimate':max(0,float(distances[j])-.015),'bestIndex':yes[j]}
def select():
    geometry_checks()
    data=read('scan-results.json');rows=data['rows'];protocol=read('protocol.json');grid=read('grid.json');sample=read('sample.json')
    points=np.array([x['p'] for x in grid]);aims=np.array([x['aims'][1] for x in grid]);radius=data['radius'];gap=2*radius+.005
    groups=collections.defaultdict(list)
    assert len(rows)==4212 and len({x['id'] for x in rows})==4212
    for row in rows:
        row['sameOriginalRoute']=row.get('rails')==row['expectedRails'];row['geometricCandidates']=[]
        if row.get('accepted'):
            stop=np.array(row['stop']);angles=angle_values(stop,points,aims,radius)
            ids=np.where((abs(angles)<=20)&(np.linalg.norm(points-stop,axis=1)>gap))[0]
            if len(ids):
                cand=points[ids]
                mask=(corridor(cand,row['cuePath'])>gap)&(corridor(cand,row['objectPath'])>gap)
                row['geometricCandidates']=ids[mask].tolist()
            pocket_centers=np.array([[p['center']['x'],p['center']['z']] for p in sample['geometry']['pockets']])
            row['minPocketCenterDistance']=float(corridor(pocket_centers,row['cuePath']).min())
        groups[(row['route'],row['nominalV'],row['tier'])].append(row)
    summaries=[]
    for (route,v,tier),all_rs in groups.items():
        assert len(all_rs)==81
        rs=[r for r in all_rs if r['offset'][1]==0]
        assert len(rs)==27
        nominal=next(r for r in rs if r['offset']==[0,0,0,0]);valid=[r for r in rs if r.get('accepted')]
        counts=np.zeros(len(points),int);comfortable=np.zeros(len(points),int)
        for r in rs:
            counts[r['geometricCandidates']]+=1
            if r.get('clearance',-1)>.1:comfortable[r['geometricCandidates']]+=1
        common=np.where(counts==27)[0].tolist();comfort=np.where(comfortable==27)[0].tolist()
        conditional=np.where(counts==len(valid))[0].tolist() if valid else []
        axis={}
        for k,name in enumerate(['speed','direction','horizontalTip','verticalTip']):
            subset=[r for r in all_rs if all(r['offset'][j]==0 for j in range(4) if j!=k)]
            assert len(subset)==3
            c=set.intersection(*(set(r['geometricCandidates']) for r in subset))
            axis[name]={'accepted':sum(bool(r.get('accepted')) for r in subset),'samples':3,'commonCount':len(c),'domainInvalid':sum(not r['inputValid'] for r in subset)}
        stops=np.array([r['stop'] for r in valid])
        scatter=float(np.linalg.norm(stops-np.array(nominal['stop']),axis=1).max()) if len(stops) and 'stop' in nominal else None
        summary={'id':f'{route}-{v:g}-{tier}','route':route,'v':v,'tier':tier,'nominalID':nominal['id'],'samples':27,'inputValid':sum(r['inputValid'] for r in rs),'accepted':len(valid),'pot':sum(bool(r.get('pot')) for r in rs),'scratch':sum(bool(r.get('scratch')) for r in rs),'incomplete':sum(r['inputValid'] and not r.get('settled',False) for r in rs),'sameOriginalRoute':sum(r.get('accepted') and r['sameOriginalRoute'] for r in rs),'nominalRails':nominal.get('rails',[]),'nominalAccepted':nominal.get('accepted',False),'nominalClearance':nominal.get('clearance'),'minimumClearance':min([r['clearance'] for r in valid],default=None),'nominalElevation':nominal.get('firstElevationDegrees'),'nominalLength':nominal.get('postContactLength'),'scatterMax':scatter,'common':common,'comfortableCommon':comfort,'conditionalCommon':conditional,'coverage90':np.where(counts>=math.ceil(.9*27))[0].tolist(),'commonShape':shape(common,points),'comfortShape':shape(comfort,points),'axis':axis,'coverage':counts.tolist(),'comfortableCoverage':comfortable.tolist()}
        summaries.append(summary)
        summary['incomplete']=sum('settled' in r and not r['settled'] for r in rs)
        summary['solverNoWitness']=sum(r.get('inputFailure')=='solver_no_pot_witness' for r in rs)
    selected=[]
    for route in protocol['routes']:
        candidates=[s for s in summaries if s['route']==route['key'] and s['tier']=='A' and s['nominalRails']==route['rails'] and s['nominalAccepted']]
        # Preserve original rail topology for the reported alternative. No hidden re-aim/spin changes.
        best=max(candidates,key=lambda s:(len(s['comfortableCommon']),len(s['common']),s['accepted'],s['minimumClearance'] or -1,-s['v'])) if candidates else None
        speeds={4.5}
        if best:speeds.add(best['v'])
        selected.extend(s['id'] for s in summaries if s['route']==route['key'] and s['v'] in speeds)
    validation=[];points_by_group={}
    for s in summaries:
        if s['id'] not in selected:continue
        route=next(r for r in protocol['routes'] if r['key']==s['route'])
        original=int(np.argmin(np.linalg.norm(points-np.array(route['ball2']),axis=1)))
        candidates=sorted(set(s['common']+[original]))
        # All common coarse-grid positions are physically checked, not only a chosen winner.
        points_by_group[s['id']]=candidates
        rs=[r for r in groups[(s['route'],s['v'],s['tier'])] if r['offset'][1]==0]
        for point_index in candidates:
            for r in rs:
                j={k:r[k] for k in ['id','route','nominalV','tier','offset','v','sx','sy','direction','pocket2','expectedRails']}
                assert r.get('inputFailure')!='solver_no_pot_witness', 'Cannot replay an unsolved direction in second-ball validation'
                j.update(id=f"{r['id']}-p{point_index}",sampleID=r['id'],group=s['id'],pointIndex=point_index,point=points[point_index].tolist())
                validation.append(j)
    save('evaluated-scan.json',{'rows':rows})
    save('summary.json',{'groups':summaries,'selected':selected,'pointsByGroup':points_by_group,'points':points.tolist(),'radius':radius})
    save('request-validate.json',{'mode':'validate','jobs':validation})
    save('geometry-checks.json',{'checks':['straight cut zero','45 degree ghost geometry','finite segment endpoint','mirror finite segment'],'passed':True})
    print('selected',selected,'validation shots',len(validation),flush=True)
    for s in summaries:
        if s['id'] in selected:print(s['id'],'accepted',s['accepted'],'common',len(s['common']),'comfort',len(s['comfortableCommon']),flush=True)
def report():
    from report import generate
    generate()
if __name__=='__main__':
    if sys.argv[1]=='select':select()
    elif sys.argv[1]=='report':report()

from common import *
import sys,hashlib,itertools

def main(stage):
 folder=OUT/stage;protocol=json.loads((folder/'protocol.json').read_text());ids=[r['rackID'] for r in protocol['racks']];variants=protocol['variants']
 bases={r['input']['rackID']:r for r in readraw(folder) if r['input']['variant']=='baseline'};assert len(bases)==len(ids)
 rows={};audits=[];angles={v:[] for v in variants};gaps={v:[] for v in variants};sources=[]
 for p in folder.glob('raw-*.jsonl.gz'):sources.append(dict(path=str(p.relative_to(ROOT)),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
 for raw in readraw(folder):
  i,v=raw['input']['rackID'],raw['input']['variant'];assert (i,v) not in rows
  assert raw['status']=='settled',(i,v,raw['status'])
  assert raw['input']['seed']==bases[i]['input']['seed']
  audit,edge,u,alignment=audit_geometry(raw,bases[i]);audits.append(audit);angles[v].append(u);gaps[v].append(edge)
  r=extract(raw);r.update(variant=v,edgeGapMM=list(map(float,edge)),neighborOffsetAlignment=alignment,**sequence(raw));rows[i,v]=r
 assert set(rows)==set(itertools.product(ids,variants))
 assert {(r['rackID'],r['seed']) for r in protocol['racks']}=={(i,bases[i]['input']['seed']) for i in ids}
 summary=dict(stage=stage,count=len(rows),seeds=len(ids),sources=sources,variants={},comparisons={},audit={k:(min(a[k] for a in audits) if k=='minGapMM' else max(a[k] for a in audits)) for k in audits[0]},edges=EDGES)
 summary['audit']['allSettled']=True;summary['audit']['nonPairJumps']=sum(r['nonPairJumps'] for r in rows.values())
 for v in variants:
  rr=[rows[i,v] for i in ids];y=np.array([r['score'] for r in rr]);u=np.array(angles[v]);eg=np.array(gaps[v]);order=np.array([r['firstImpulseOrder'] for r in rr],dtype=float);tm=np.array([r['firstImpulseMS'] for r in rr],dtype=float)
  baselineOrder=np.array([rows[i,'baseline']['firstImpulseOrder'] for i in ids],dtype=float);x=np.array([r['neighborOffsetAlignment'] for r in rr])
  uc=u-u.mean(0)
  centered=float(np.mean([np.sum(uc[:,a]*uc[:,b])/np.sqrt(np.sum(uc[:,a]**2)*np.sum(uc[:,b]**2)) for a,b in EDGES]))
  gapcorr=np.corrcoef(eg.T)
  disjoint=float(np.mean([gapcorr[a,b] for a in range(30) for b in range(a+1,30) if not set(EDGES[a])&set(EDGES[b])]))
  summary['variants'][v]=dict(centeredNeighborDirectionCorrelation=centered,disjointEdgeGapCorrelation=disjoint,edgeGapCorrelation=gapcorr.tolist(),**stats(rr),cpuMeanMS=float(np.mean([r['cpuMS'] for r in rr])),p10=float(np.quantile(y,.1)),edgeGapMeanMM=eg.mean(0).tolist(),edgeGapSDMM=eg.std(0).tolist(),neighborOffsetAlignment=float(x.mean()),perBallAngularMean=u.mean(0).tolist(),meanFirstImpulseOrder=np.nanmean(order,axis=0).tolist(),meanFirstImpulseMS=np.nanmean(tm,axis=0).tolist(),firstImpulseObservedPerBall=np.sum(~np.isnan(order),axis=0).tolist(),censoredRackCount=sum(bool(r['censoredSlots']) for r in rr),changedFirstOrderRacks=int(np.sum(np.any(~np.isclose(order,baselineOrder,equal_nan=True),axis=1))),earlyJumpsMean=float(np.mean([len(r['sequence20']) for r in rr])),firstInternalBeforeCornerRate=float(np.mean([r['firstInternalBeforeEitherCorner'] for r in rr if r['firstInternalBeforeEitherCorner'] is not None])),meanInternalFirstOrder=float(np.mean([r['meanInternalFirstOrder'] for r in rr if r['meanInternalFirstOrder'] is not None])),mechanisms={f:float(np.mean([r['features']['5'][f] for r in rr])) for f in rr[0]['features']['5']})
 if stage=='discovery':
  ranking=sorted((v for v in variants if v not in ['baseline','toward']),key=lambda v:(-summary['variants'][v]['mean'],v));summary['ranking']=ranking;summary['selected']=ranking[:2]
  plan=json.loads((OUT/'validation-plan.json').read_text());del plan['variantsPending'];plan['variants']=['baseline','toward']+ranking[:2];plan['selection']=dict(rule=protocol['selection'],discoveryProtocolSHA=hashlib.sha256((folder/'protocol.json').read_bytes()).hexdigest())
  assert not (OUT/'validation/protocol.json').exists();write(OUT/'validation/protocol.json',plan)
 else:
  comps=[(v,'baseline') for v in variants if v!='baseline']+[(v,'toward') for v in variants if v not in ['baseline','toward']]
  if stage=='confirmation':comps=[('radial_contract',ref) for ref in ['baseline','toward','radial_independent']]+[('radial_independent','baseline')]
  family=len(comps);split=len(ids)//2
  for v,ref in comps:
   d=np.array([rows[i,v]['score']-rows[i,ref]['score'] for i in ids]);ds={f:np.array([rows[i,v]['features']['5'][f]-rows[i,ref]['features']['5'][f] for i in ids]) for f in rows[ids[0],v]['features']['5']}
   summary['comparisons'][v+'--'+ref]=dict(**ci(d,family),relativeMeanChange=float(d.mean()/summary['variants'][ref]['mean']),better=int(np.sum(d>1e-12)),halfMeans=[float(d[:split].mean()),float(d[split:].mean())],wallDelta=ci([rows[i,v]['wallMS']-rows[i,ref]['wallMS'] for i in ids],family),diagnosticDeltaCorrelations={f:float(np.corrcoef(d,x)[0,1]) if x.std()>0 else None for f,x in ds.items()})
 binding=json.loads((folder/'source-binding.json').read_text());drift=[x['path'] for x in binding['production'] if hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()!=x['sha256']];assert not drift;summary['audit']['sourceDrift']=drift
 write(folder/'rows.json',[rows[i,v] for i in ids for v in variants]);write(folder/'summary.json',summary)
 print(json.dumps(dict(audit=summary['audit'],selected=summary.get('selected'),means={v:{k:r[k] for k in ['mean','passRate','wallMeanMS','neighborOffsetAlignment']} for v,r in summary['variants'].items()},comparisons=summary['comparisons']),indent=2))
if __name__=='__main__':main(sys.argv[1])

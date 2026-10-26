from analyze import *
# Geometry identity: first-order edge-length sum depends on boundary displacements.
pp=NOM.astype(float);M=np.zeros((len(EDGES),15,2));degree=np.zeros(15,dtype=int);nominal=[]
for j,(a,b) in enumerate(EDGES):
 v=pp[b]-pp[a];dist=np.linalg.norm(v);n=v/dist;M[j,a]=-n;M[j,b]=n;degree[a]+=1;degree[b]+=1;nominal.append(dist)
coefficient=M.sum(0);interior=[4,7,8]
assert np.all(degree[interior]==6) and np.linalg.norm(coefficient[interior],axis=1).max()<2e-6
nominal=np.array(nominal);by={}
for raw in readraw(OUT/'discovery'):
 if raw['input']['variant'] not in ['radial_contract','radial_coreFlip']:continue
 p=np.array([[r['x'],r['z']] for r in raw['rack']]);u=p-pp;linear=np.einsum('eij,ij->e',M,u);rel=np.array([u[b]-u[a] for a,b in EDGES]);rr=np.linalg.norm(rel,axis=1)
 exact=np.array([np.linalg.norm(p[b]-p[a]) for a,b in EDGES]);remainder=exact-nominal-linear
 bound=rr*rr/(2*(nominal-rr))
 assert remainder.min()>-1e-15 and np.all(remainder<=bound+1e-15)
 by[raw['input']['rackID'],raw['input']['variant']]=dict(p=p,linear=linear,exact=exact,remainder=remainder)
rows=[]
for i in sorted({i for i,v in by}):
 base=by[i,'radial_contract'];alt=by[i,'radial_coreFlip'];dp=alt['p']-base['p'];assert np.max(np.abs(dp[~CORE]))==0
 linearDelta=float(np.mean(alt['linear']-base['linear']));assert abs(linearDelta)<1e-10
 rows.append(dict(id=i,linearMeanGapDeltaMM=linearDelta*1000,exactMeanGapDeltaMM=float(np.mean(alt['exact']-base['exact'])*1000),maxSecondOrderMM=max(float(base['remainder'].max()),float(alt['remainder'].max()))*1000))
summary=dict(source='First-order Taylor expansion of Euclidean edge lengths; computed nominal graph, not a collision solver approximation.',edgeCount=len(EDGES),degree=degree.tolist(),displacementCoefficients=coefficient.tolist(),internalCoefficientNorms=np.linalg.norm(coefficient[interior],axis=1).tolist(),n=len(rows),maxAbsLinearMeanGapDeltaMM=max(abs(r['linearMeanGapDeltaMM']) for r in rows),meanExactMeanGapDeltaMM=float(np.mean([r['exactMeanGapDeltaMM'] for r in rows])),maxAbsExactMeanGapDeltaMM=max(abs(r['exactMeanGapDeltaMM']) for r in rows),maxSecondOrderMM=max(r['maxSecondOrderMM'] for r in rows),allSecondOrderBoundsPassed=True,scope='Only local geometric gap-sum cancellation; does not prove which collision order maximizes final spread. coreFlip outcomes are exploratory discovery only.')
write(OUT/'geometry-network.json',summary);write(OUT/'geometry-network-rows.json',rows);print(json.dumps(summary,indent=2))

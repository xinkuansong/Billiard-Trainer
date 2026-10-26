from analyze import *
# Analytic directional law check; no physical simulation or fitted data involved.
vs=json.loads((OUT/'discovery/protocol.json').read_text())['variants'][1:]
phis=np.arange(1440)*2*np.pi/1440;summary={};ref=np.array([canonical_transform([math.cos(a),math.sin(a)],'radial_contract') for a in phis])
refangles=np.arctan2(ref[:,:,1],-ref[:,:,0])
for v in vs:
 cc=np.array([canonical_transform([math.cos(a),math.sin(a)],v) for a in phis])
 assert np.max(np.abs(np.linalg.norm(cc,axis=2)-1))<1e-14 and cc[:,:,0].max()<1e-14
 aa=np.arctan2(cc[:,:,1],-cc[:,:,0]);error=float(np.max(np.abs(np.sort(aa,axis=0)-np.sort(refangles,axis=0))))
 assert error<1e-12,(v,error)
 summary[v]=dict(maxSortedAngleError=error,meanCanonicalX=float(cc[:,:,0].mean()),meanCanonicalZ=float(cc[:,:,1].mean()))
# Hand-check standard cases: original canonical (+1,0), core P30 -> (-sqrt(3)/2,+1/2).
x=canonical_transform([1.,0.],'radial_coreP30');assert np.allclose(x[[4,7,8]],[-math.sqrt(3)/2,.5]) and np.allclose(x[~CORE],[-1,0])
x=canonical_transform([0.,1.],'radial_sideFlip');assert np.allclose(x[NOM[:,1]<0],[0,-1]) and np.allclose(x[NOM[:,1]>=0],[0,1])
write(OUT/'marginal-check.json',dict(angularGrid=1440,allInward=True,unitNorm=True,sameMarginalDirectionDistribution=True,variants=summary));print('16 policies: inward range, norm, marginal law and standard geometry checks passed.')

from place import *
c=np.array([-.8,0.]);t=np.array([.8,0.])
assert direct_certificate(c,t,np.array([0.,0.]))
assert not direct_certificate(c,t,np.array([0.,.2]))
assert not direct_certificate(c,t,np.array([1.,0.]))
assert not direct_certificate(c,t,np.array([-.79,0.]))
track=[[0,0,0],[1,1,0],[2,1,1]]
p=np.array([[.5,.1],[1.1,.5],[2.,2.]])
assert np.allclose(pathdist(p,track),[.1,.1,math.sqrt(2)])
# Independent straight-ray checks cover every target-contact heading in this example.
b=np.array([0.,0.]);axis=math.atan2(*(t-c)[::-1]);half=math.asin(D/np.linalg.norm(t-c))
for angle in np.linspace(axis-half,axis+half,1001):
 u=np.array([math.cos(angle),math.sin(angle)])
 def entry(q):
  v=q-c;projection=np.dot(v,u);discriminant=D*D-(np.dot(v,v)-projection*projection)
  assert discriminant>=-1e-12
  return projection-math.sqrt(max(0,discriminant))
 assert entry(b)<entry(t)
(OUT/'geometry-selftest.json').write_text(json.dumps({'passed':True,'cases':6,'rayChecks':1001,'scope':'Straight planar swept-circle geometry; no physical uniqueness claim.'},indent=2))
print('GEOMETRY SELFTEST 6 cases + 1001 straight-ray checks passed')

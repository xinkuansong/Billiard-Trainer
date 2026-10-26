from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];PREV=ROOT/'research/rack-phase-tuning-20261026'
s=(PREV/'analyze.py').read_text().replace('rack-phase-tuning-20261026',HERE.name)
a=s.index('def expected(');b=s.index('def geometry(',a)
s=s[:a]+'''ROW=np.array([r for r in range(5) for c in range(r+1)])
CORE=np.array([i in [4,7,8] for i in range(15)])
def canonical_transform(c,v):
 if v=='radial_contract':return np.tile([-abs(c[0]),c[1]],(15,1))
 suffix=v.split('_')[1];region=next(g for g in ['core','side','front'] if suffix.startswith(g));mode=suffix[len(region):]
 if mode=='Flip':
  mask=CORE if region=='core' else ROW<=2 if region=='front' else NOM[:,1]<0
  result=np.tile(c,(15,1));result[mask,1]*=-1
 else:
  degree=int(mode[1:])*(-1 if mode[0]=='M' else 1)
  weights=CORE.astype(float) if region=='core' else (ROW<=2).astype(float) if region=='front' else np.sign(NOM[:,1].astype(float))*.5
  angles=np.deg2rad(degree*weights);cs,sn=np.cos(angles),np.sin(angles)
  result=np.column_stack([cs*c[0]-sn*c[1],sn*c[0]+cs*c[1]])
 result[:,0]=-np.abs(result[:,0]);return result

def expected(bp,v):
 if v in ('baseline','radial_contract'):return old.expected(bp,v)
 d=bp-NOM;r=np.linalg.norm(d,axis=1);u=d/np.where(r>0,r,1)[:,None];u[r==0]=[1,0]
 can=np.column_stack([np.sum(u*q,axis=1),np.sum(u*t,axis=1)]);c=can.mean(0)
 if np.linalg.norm(c)<1e-12:
  cc=np.array([canonical_transform(can[i],v)[i] for i in range(15)])
 else:cc=canonical_transform(c,v)
 cc/=np.linalg.norm(cc,axis=1)[:,None]
 return np.float32(NOM.astype(float)+r[:,None]*(q*cc[:,0,None]+t*cc[:,1,None]))
''' +s[b:]
# All source guards strict here; only build-time frozen-vs-current exact wrapper difference is permitted.
a=s.index(" binding=json.loads((folder/'source-binding.json').read_text())");b=s.index(" result['audit'].update",a)
s=s[:a]+" binding=json.loads((folder/'source-binding.json').read_text());assert all(hashlib.sha256((ROOT/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in binding['production'])\n"+s[b:]
needle="  result['variants'][v]['signDiagnostics']="
idx=s.index(needle)
s=s[:idx]+'''  result['variants'][v]['earlyJumpsMean']=float(np.mean([len(r['sequence20']) for r in rr]))
  result['variants'][v]['internalFirstOrder']=float(np.mean([r['meanInternalFirstOrder'] for r in rr if r['meanInternalFirstOrder'] is not None]))
  result['variants'][v]['internalFirstOrderN']=sum(r['meanInternalFirstOrder'] is not None for r in rr)
  result['variants'][v]['edgeGroupMeansMM']={str(k):float(np.mean([[r['edgeGapMM'][j] for j,(a,b) in enumerate(EDGES) if int(CORE[a])+int(CORE[b])==k] for r in rr])) for k in [0,1,2]}
''' +s[idx:]
(HERE/'analyze.py').write_text(s)

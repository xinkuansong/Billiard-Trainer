from pathlib import Path
import json,ctypes,math,itertools,csv,time
import numpy as np
OUT=Path(__file__).resolve().parent
lib=ctypes.CDLL(str(OUT/'metrics.dylib'));fn=lib.metrics
PTR=ctypes.POINTER(ctypes.c_double);fn.argtypes=[PTR,ctypes.c_int,PTR,ctypes.c_int,PTR];fn.restype=None
KEYS=['frechet','dtw','chamfer','pathLength','dtwSymmetric2','dtwTotal']
def calc(p,q):
    a=np.ascontiguousarray(p,dtype=np.float64);b=np.ascontiguousarray(q,dtype=np.float64)
    if len(a)==0 or len(b)==0 or not np.isfinite(a).all() or not np.isfinite(b).all():raise ValueError('Invalid trajectory')
    out=np.empty(6);fn(a.ctypes.data_as(PTR),len(a),b.ctypes.data_as(PTR),len(b),out.ctypes.data_as(PTR))
    return dict(zip(KEYS,out.tolist()))
def save(name,data): (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False))
def clean(p):
    p=np.asarray(p,dtype=float)
    if p.ndim!=2 or p.shape[1]!=2 or not len(p) or not np.isfinite(p).all():raise ValueError('Invalid polyline')
    return p[np.r_[True,np.any(np.diff(p,axis=0)!=0,axis=1)]]
def arc(p):return np.r_[0,np.cumsum(np.linalg.norm(np.diff(p,axis=0),axis=1))]
def sample(p,n,anchors=()):
    p=clean(p);s=arc(p)
    if s[-1]==0:return p.copy(),{'count':1,'length':0.,'maxEdge':0.,'reconstructionError':0.}
    # Global uniform grid plus exact event vertices. N is a budget, never a hard cap.
    ids=[0,len(p)-1]+list(anchors)
    loc=np.unique(np.r_[np.linspace(0,s[-1],n),s[ids]])
    out=np.column_stack([np.interp(loc,s,p[:,axis]) for axis in range(2)])
    # Same-source-arc monotone correspondence; bounds polyline approximation error.
    approx=np.column_stack([np.interp(s,loc,out[:,axis]) for axis in range(2)])
    error=float(np.max(np.linalg.norm(p-approx,axis=1)))
    return out,{'count':len(out),'length':float(s[-1]),'maxEdge':float(max(np.linalg.norm(np.diff(out,axis=0),axis=1))),'reconstructionError':error}
def geometric_anchors(p):
    p=clean(p);ids=[0,len(p)-1]
    for i in range(1,len(p)-1):
        u=p[i]-p[i-1];v=p[i+1]-p[i]
        if abs(u[0]*v[1]-u[1]*v[0])>1e-10 or np.dot(u,v)<=0:ids.append(i)
    return sorted(set(ids))
def synthetic():
    line=np.array([[-100.,0],[100,0]])
    return {
      'identical':(line,line,'完全重合'),
      'offset_2':(line,line+[0,2],'平行偏移 2 cm'),
      'offset_5':(line,line+[0,5],'平行偏移 5 cm'),
      'local_spike':(line,np.array([[-100,0],[-2,0],[0,20],[2,0],[100,0]]),'局部偏离 20 cm'),
      'late_branch':(line,np.array([[-100,0],[0,0],[100,30]]),'前半重合、后半分叉'),
      'truncated':(line,np.array([[-100,0],[40,0]]),'同路但少走 60 cm'),
      'reverse':(line,line[::-1],'同一路径方向相反'),
      'retrace':(line,np.array([[-100,0],[100,0],[-100,0],[100,0]]),'同一空间路径反复走'),
      'loop_order':(np.array([[0,0],[-60,-40],[-60,40],[0,0],[60,-40],[60,40],[0,0]]),np.array([[0,0],[60,-40],[60,40],[0,0],[-60,-40],[-60,40],[0,0]]),'交叉闭环、遍历次序不同'),
      'corner':(np.array([[-100,40],[0,-60],[100,40]]),np.array([[-100,40],[0,-50],[100,40]]),'关键折点偏移 10 cm'),
      'stationary':(np.array([[0,0],[0,0]]),np.array([[3,4]]),'静止点相距 5 cm'),
      'uneven_source':(line,np.array([[-100,0],[-99.99,0],[-99,0],[0,0],[100,0]]),'同路、原始采样不均')}
def brute(p,q):
    vals=[]
    def go(i,j,dist):
        dist=dist+[float(np.linalg.norm(p[i]-q[j]))]
        if i==len(p)-1 and j==len(q)-1: vals.append((max(dist),sum(dist),len(dist)));return
        for di,dj in [(1,0),(0,1),(1,1)]:
            if i+di<len(p) and j+dj<len(q):go(i+di,j+dj,dist)
    go(0,0,[]);best=min(vals,key=lambda x:(x[1],x[2]));return min(x[0] for x in vals),best[1]/best[2]
def tests():
    rng=np.random.default_rng(20261022);count=0
    for n,m in [(1,1),(1,4),(2,3),(3,3),(4,4)]:
      for _ in range(12):
        p=rng.normal(size=(n,2));q=rng.normal(size=(m,2));r=calc(p,q);f,d=brute(p,q)
        assert abs(r['frechet']-f)<1e-10 and abs(r['dtw']-d)<1e-10
        rev=calc(q,p)
        for key in ['frechet','dtw','chamfer','dtwSymmetric2']:assert abs(r[key]-rev[key])<1e-10
        assert r['frechet']+1e-10>=max(np.linalg.norm(p[0]-q[0]),np.linalg.norm(p[-1]-q[-1]))
        count+=1
    for invalid in [[],[[float('nan'),0]],[[float('inf'),1]]]:
        try:clean(invalid)
        except ValueError:pass
        else:raise AssertionError('invalid accepted')
    p=np.array([[0.,0],[10,0],[10,20]])
    s,meta=sample(p,128,[0,1,2]);assert np.min(np.linalg.norm(s-[10,0],axis=1))==0 and meta['reconstructionError']<1e-10
    # These scores have closed-form ground truths, independent of DP recurrence.
    for name in ['identical','offset_2','offset_5','reverse','stationary','uneven_source']:
        a,b,_=synthetic()[name];p,_=sample(a,512);q,_=sample(b,512);r=calc(p,q)
        expected={'identical':0,'offset_2':2,'offset_5':5,'reverse':200,'stationary':5,'uneven_source':0}[name]
        assert abs(r['frechet']-expected)<1e-9
        if name=='reverse':assert r['chamfer']<1e-10
    save('algorithm-tests.json',{'passed':True,'exhaustiveSmallPairs':count,'checks':['enumerated all monotone paths','symmetry','endpoint lower bound','closed-form distances','invalid input rejection','corner retention']})
def post_contact(row):
    # This fixed simulator fixture contains exactly one object ball.
    events=[e for e in row['events'] if e['kind']=='ball']
    if not events:raise ValueError('No target contact')
    event=min(events,key=lambda e:e['time']);t=event['time']
    times=np.asarray(row['times']);points=np.asarray(row['points_m'])
    assert len(times)==len(points) and np.all(np.diff(times)>=0)
    exact=np.flatnonzero(times==t)
    if not len(exact):raise ValueError('Missing exact contact sample')
    i=int(exact[-1]) # last committed state at the contact timestamp
    assert np.linalg.norm(points[i]-event['position'])<1e-12
    result={**row,'points_m':points[i:].tolist(),'times':times[i:].tolist(),
      'events':[e for e in row['events'] if e['time']>=t],
      'rawFrames':[f for f in row.get('rawFrames',[]) if f['time']>=t]}
    info={'id':row['id'],'contactTime':t,'contactPosition_m':event['position'],'trimIndex':i,
      'removedApproachLength_cm':float(arc(points[:i+1]*100)[-1]),
      'postContactPointCount':len(points)-i,'startMatchesContact':True,
      'endUnchanged':bool(np.array_equal(points[-1],result['points_m'][-1])),
      'noPrecontactTimes':bool(np.all(times[i:]>=t))}
    assert info['endUnchanged'] and info['noPrecontactTimes']
    return result,info

def scope_tests():
    event={'kind':'ball','time':1.,'position':[1.,0.]}
    row={'id':'test','times':[0.,1.,1.,2.], 'points_m':[[0,0],[1,0],[1,0],[2,0]],
         'events':[event,{'kind':'cushion','time':2.,'position':[2.,0.]}]}
    clipped,audit=post_contact(row)
    assert audit['trimIndex']==2 and clipped['points_m']==[[1.,0.],[2.,0.]] and len(clipped['events'])==2
    still={**row,'times':[0.,1.],'points_m':[[0,0],[1,0]],'events':[event]}
    assert len(post_contact(still)[0]['points_m'])==1
    try:post_contact({**row,'events':[]})
    except ValueError:pass
    else:raise AssertionError('No-contact trajectory accepted')
    return ['no contact rejected','last same-time committed sample','stationary contact accepted','end and later cushion retained']

def main():
    tests();scope_checks=scope_tests();raw=json.loads((OUT/'engine-trajectories.json').read_text());trajectories={};meta={};trimmed=[];audits=[];excluded=[]
    for original in raw['rows']:
        if not any(e['kind']=='ball' for e in original['events']):
            excluded.append({'id':original['id'],'reason':'No target-ball contact'});continue
        row,audit=post_contact(original);trimmed.append(row);audits.append(audit)
        p=clean(np.array(row['points_m'])*100);anchors=[0,len(p)-1]
        # Actual collision positions must be exact source vertices (within Float serialization tolerance).
        for event in row['events']:
            dist=np.linalg.norm(p-np.array(event['position'])*100,axis=1);i=int(np.argmin(dist));assert dist[i]<1e-5;anchors.append(i)
        trajectories[row['id']]=(p,sorted(set(anchors)))
        meta[row['id']]={k:v for k,v in row.items() if k not in ['points_m','times','rawFrames']}
        meta[row['id']].update(audit)
        meta[row['id']]['length_cm']=float(arc(p)[-1]);meta[row['id']]['rawPointCount']=len(p)
    save('post-contact-trajectories.json',{**raw,'rows':trimmed,'scope':'first cue-target contact to physical termination'})
    save('scope-validation.json',{'passed':True,'included':audits,'excluded':excluded,'checks':scope_checks})
    # Per-input resampling cache, preserving event order and identity.
    cache={};sampling=[]
    for n in [128,256,512,1024,2048]:
      for name,(p,anchors) in trajectories.items():
        q,m=sample(p,n,anchors);cache[name,n]=q;sampling.append({'id':name,'budget':n,**m})
    pairs=[]
    for a,b in itertools.combinations(trajectories,2):
      for n in [128,256,512,1024,2048]:pairs.append({'a':a,'b':b,'budget':n,**calc(cache[a,n],cache[b,n])})
    cases=[]
    for name,(a,b,label) in synthetic().items():
      for n in [128,256,512,1024,2048]:
        p,pm=sample(a,n,geometric_anchors(a));q,qm=sample(b,n,geometric_anchors(b))
        cases.append({'id':name,'label':label,'budget':n,'a':p.tolist() if n==512 else [],'b':q.tolist() if n==512 else [],'samplingA':pm,'samplingB':qm,**calc(p,q)})
    save('metrics.json',{'engine':pairs,'synthetic':cases,'sampling':sampling,'metadata':meta})
    save('display-trajectories.json',{name:cache[name,512].tolist() for name in trajectories})
    # Swift independent conformance fixture, including all real pairs at 512.
    save('swift-fixtures.json',[{'a':cache[r['a'],512].tolist(),'b':cache[r['b'],512].tolist(),'expected':[r[k] for k in ['frechet','dtw','chamfer']]} for r in pairs if r['budget']==512])
    for name,rows in [('engine-pairs.csv',pairs),('synthetic-cases.csv',[{k:v for k,v in r.items() if k not in ['a','b','samplingA','samplingB']} for r in cases]),('sampling.csv',sampling)]:
      with (OUT/name).open('w') as f:w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
    print('DONE',len(pairs),'engine comparisons;',len(cases),'synthetic comparisons',flush=True)
if __name__=='__main__':main()

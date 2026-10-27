from pathlib import Path
import json,gzip,math,hashlib
import numpy as np
O=Path('output/rack-spin-forensics-20261027')
r=json.loads(next(iter(gzip.open(O/'raw.jsonl.gz','rt'))));old=json.loads((O/'frames.json').read_text())
for k in ['frames','board','contacts','duration','rack','initialCueVelocity']:assert r[k]==old[k],k
params=json.load(open('output/rack-fixed-physics-20261027/audit.json'))['parameters']
R=params['ballRadius'];m=params['ballMass'];I=.4*m*R*R;g=params['gravity'];mus=params['slidingFriction'];mur=params['rollingFriction'];alpha=2.5*params['spinFriction']*g/R
U=np.array([0.,1.,0.]);V=lambda x:np.array(x,dtype=float);norm=np.linalg.norm
names=['_12','_1'];events=r['eventTrace']
def energy(s):
 v,w=V(s['v']),V(s['w']);return dict(linear=.5*m*float(v@v),axialSpin=.5*I*w[1]**2,otherSpin=.5*I*(w[0]**2+w[2]**2),total=.5*m*float(v@v)+.5*I*float(w@w))
def coast(s):
 v,w=V(s['v']),V(s['w']);u=v+np.cross(w,-R*U);ts=2*norm(u)/(7*mus*g) if s['state']=='sliding' else 0
 vr=v-2*u/7 if s['state']=='sliding' else v
 if s['state'] in ['stationary','spinning']:ts=0.;vr=V([0,0,0])
 return dict(slipSpeed=float(norm(u)),slideTime=float(ts),rollingVelocity=vr.tolist(),rollingSpeed=float(norm(vr)),rollTime=float(norm(vr)/(mur*g)),translationStopAfter=float(ts+norm(vr)/(mur*g)),spinStopAfter=float(abs(w[1])/alpha))
def summary(s):return dict(speed=float(norm(V(s['v']))),wy=s['w'][1],energy=energy(s),coast=coast(s))
def cushion_ref(e):
 a=e['pre'];v,w=V(a['v']),V(a['w']);N=V(e['normal']);N/=norm(N)
 if v@N<0:N=-N
 sn=params['cushionHeight']/R-1;cs=math.sqrt(1-sn*sn)
 n=-cs*N-sn*U;arm=-R*n;rel=v+np.cross(w,arm);normalSpeed=float(rel@n);slip=rel-n*normalSpeed
 Jn=-(1+params['cushionRestitution'])*m*normalSpeed;needed=m*norm(slip)/3.5;cap=params['cushionFriction']*Jn
 Jt=-m*slip/3.5
 branch='sticking' if needed<=cap else 'sliding'
 if norm(Jt)>cap:Jt*=cap/norm(Jt)
 J=Jn*n+Jt;v3=v+J/m;vp=v3.copy();vp[1]=0;wp=w+np.cross(arm,J)/I
 out=e['post'];obsJ=m*(V(out['v'])-v)
 return dict(normal=N.tolist(),contactArm=arm.tolist(),contactNormal=n.tolist(),contactSlip=slip.tolist(),slipSpeed=float(norm(slip)),branch=branch,normalImpulse=Jn,tangentImpulse=Jt.tolist(),tangentImpulseMagnitude=float(norm(Jt)),frictionCap=cap,impulse=J.tolist(),torqueImpulse=np.cross(arm,J).tolist(),predV=vp.tolist(),predW=wp.tolist(),maxVError=float(norm(vp-V(out['v']))),maxWError=float(norm(wp-V(out['w']))),freeVerticalVelocity=float(v3[1]),fullContactRestitutionResidual=float((v3+np.cross(wp,arm))@n+params['cushionRestitution']*normalSpeed),observedPlanarEffectiveRestitution=float(-V(out['v'])@n/normalSpeed),observedHorizontalImpulse=obsJ.tolist())
def pair_ref(e):
 a,b=e['preA'],e['preB'];va,vb,wa,wb=map(V,[a['v'],b['v'],a['w'],b['w']]);n=V(b['p'])-V(a['p']);n[1]=0;n/=norm(n)
 rel=va-vb+np.cross(wa+wb,n)*R;closing=float((va-vb)@n);u=rel-n*float(rel@n)
 # Retain the production model's existing post-normal-relative-speed cap.
 mu=float(np.float32(.009951)+np.float32(.108)*np.exp(np.float32(-1.088)*np.float32(norm(u))))
 jn=-.5*(1+params['ballRestitution'])*closing
 jt=-u/7;limit=mu*params['ballRestitution']*abs(closing)
 if norm(jt)>limit:jt*=limit/norm(jt)
 impulse=n*jn+jt;dw=np.cross(n,jt)*2.5/R
 av=va+impulse;bv=vb-impulse;av[1]=bv[1]=0
 return dict(normal=n.tolist(),closing=closing,contactSlip=u.tolist(),friction=mu,normalImpulsePerMass=jn,tangentImpulsePerMass=jt.tolist(),maxVError=max(float(norm(av-V(e['postA']['v']))),float(norm(bv-V(e['postB']['v'])))),maxWError=max(float(norm(wa+dw-V(e['postA']['w']))),float(norm(wb+dw-V(e['postB']['w'])))),linearMomentumResidual=(m*(V(e['postA']['v'])+V(e['postB']['v'])-va-vb)).tolist(),totalEnergyChange=energy(e['postA'])['total']+energy(e['postB'])['total']-energy(a)['total']-energy(b)['total'])
ledger={};checks=[]
for name in names:
 rows=[]
 for index,e in enumerate(events):
  if e['kind']=='ball':
   if name not in [e['preA']['name'],e['preB']['name']]:continue
   side='A' if e['preA']['name']==name else 'B';a,b=e['pre'+side],e['post'+side];other=e['preB' if side=='A' else 'preA']['name'];ref=pair_ref(e)
  else:
   if e['pre']['name']!=name:continue
   a,b=e['pre'],e['post'];other='cushion_'+str(e['index']) if e['kind']=='cushion' else b['state'];ref=cushion_ref(e) if e['kind']=='cushion' else None
  row=dict(event=index,t=e['t'],kind=e['kind'],other=other,pre=a,post=b,before=summary(a),after=summary(b),reference=ref)
  rows.append(row)
  if ref:checks.append(dict(event=index,ball=name,kind=e['kind'],vError=ref['maxVError'],wError=ref['maxWError']))
 ledger[name]=rows
# Independent free motion, compared between every recorded pair of frames. Impulses
# are isolated using the event ledger, rather than inferred from elapsed time alone.
def evolve(a,dt):
 p,v,w=map(V,[a['p'],a['v'],a['w']]);state=a['state'];p=p.copy();v=v.copy();w=w.copy()
 if state=='sliding':
  u=v+np.cross(w,-R*U);uh=u/norm(u)
  p+=v*dt-.5*mus*g*dt*dt*uh;v-=mus*g*dt*uh;w-=np.cross(uh,U)*2.5*mus*g*dt/R
 elif state=='rolling':
  vh=v/norm(v);p+=v*dt-.5*mur*g*dt*dt*vh;v-=mur*g*dt*vh;wr=np.cross(U,v)/R;w[0]=wr[0];w[2]=wr[2]
 if state in ['sliding','rolling','spinning']:w[1]=math.copysign(max(0,abs(w[1])-alpha*dt),w[1])
 return dict(p=p.tolist(),v=v.tolist(),w=w.tolist(),state=state)
continuous={};stops={}
for name in names:
 fs=r['frames'][r['names'].index(name)];err=[];impulses=[]
 ownEvents=ledger[name]
 for i,(a,b) in enumerate(zip(fs,fs[1:])):
  pred=evolve(a,b['t']-a['t'])
  dv=norm(V(pred['v'])-V(b['v']));dw=norm(V(pred['w'])-V(b['w']))
  # All large residuals must be explained by a logged contact or state transition.
  matched=[e for e in ownEvents if e['t']==b['t']]
  if matched:continue
  err.append(dict(i=i,dv=float(dv),dw=float(dw),dp=float(norm(V(pred['p'])-V(b['p'])))))
 continuous[name]=dict(n=len(err),maxV=max(x['dv'] for x in err),maxW=max(x['dw'] for x in err),maxP=max(x['dp'] for x in err))
 last=next(x for x in reversed(ownEvents) if x['kind']!='transition');lastState=last['post'];q=coast(lastState)
 lastMove=max(i for i,x in enumerate(fs) if x['state'] in ['sliding','rolling']);actualMove=fs[lastMove+1]['t']
 stationary=next(x['t'] for x in fs if x['t']>last['t'] and x['state']=='stationary')
 predictedMove=last['t']+q['translationStopAfter'];predictedSpin=last['t']+q['spinStopAfter']
 stops[name]=dict(lastCollision=last['t'],lastState=lastState,coast=q,predictedTranslationStop=predictedMove,actualTranslationStop=actualMove,predictedSpinZero=predictedSpin,actualStationary=stationary,predictedStationary=max(predictedMove,predictedSpin),stationaryError=abs(max(predictedMove,predictedSpin)-stationary),translationError=abs(predictedMove-actualMove))
 if name=='_1':
  near=min(fs,key=lambda x:abs(x['t']-predictedSpin));stops[name]['nearSpinZero']=near
# Pair transfer mechanism, with totals of both balls and axial-spin partition.
late=[e for e in ledger['_12'] if e['kind']=='ball' and e['t']>.1]
a,b=late[0]['before'],late[-1]['after']
mechanism=dict(latePairLinearReductionIncludingCoast=1-b['energy']['linear']/a['energy']['linear'],latePairAxialEnergyRetentionIncludingCoast=b['energy']['axialSpin']/a['energy']['axialSpin'],globalTranslationStop=json.load(open(O/'trace.json'))['lastTranslation'],latePairs=late)
checksMax=dict(v=max(x['vError'] for x in checks),w=max(x['wError'] for x in checks))
audit=dict(exactReplay=True,frameCount=len(r['frames'][0]),events=len(events),constants=params,spinDeceleration=alpha,collisionChecks=checks,maxErrors=checksMax,continuous=continuous,stops=stops)
for n,v in [('ledger',ledger),('audit',audit),('mechanism',mechanism)]: (O/(n+'.json')).write_text(json.dumps(v,indent=2))
print('collision error',checksMax,'continuous',continuous)
for name,rows in ledger.items():
 print('\n',name)
 for x in rows:
  a,b=x['before'],x['after'];print(f"{x['event']:3d} {x['t']:9.6f} {x['kind']:10} {x['other']:12} v {a['speed']:8.4f}->{b['speed']:8.4f} wy {a['wy']:9.4f}->{b['wy']:9.4f} Elinear {a['energy']['linear']:.5f}->{b['energy']['linear']:.5f} Espin {a['energy']['axialSpin']:.5f}->{b['energy']['axialSpin']:.5f}")
 print('stops',stops[name])
print('mechanism',mechanism['latePairLinearReductionIncludingCoast'],mechanism['latePairAxialEnergyRetentionIncludingCoast'])
# Predeclared Float32 vs independent Double tolerances (not exact parity).
assert checksMax['v']<2e-5 and checksMax['w']<.002
assert all(v['maxV']<2e-5 and v['maxW']<.002 and v['maxP']<2e-5 for v in continuous.values())
assert all(v['translationError']<.0002 and v['stationaryError']<.0002 for v in stops.values())
assert all(x['reference']['totalEnergyChange']<1e-6 for x in late)

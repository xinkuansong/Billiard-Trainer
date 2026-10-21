"""Vectorized, frictionless 2D geometry. Inputs are C, O and fixed P only."""
from pathlib import Path
import json
import numpy as np

HERE = Path(__file__).resolve().parent
RAW = json.loads((HERE/'geometry.json').read_text())
UNIT = RAW['length_m']/8
D = RAW['diameter_m']/UNIT
R = D/2
SHIFT = np.array([4., 2.])
IDEAL_P = np.array([[0,0],[8,0],[0,4],[8,4],[4,0],[4,4]], float)
REAL_P = np.array([p['center'] for p in RAW['pockets']])/UNIT+SHIFT
FRACTIONS = np.array([1., .75, .5, .25, .125])
ANCHORS = np.arcsin(1-FRACTIONS)

def cross(a,b): return a[...,0]*b[...,1]-a[...,1]*b[...,0]
def dot(a,b): return np.sum(a*b,axis=-1)
def norm(a): return np.sqrt(dot(a,a))
def unit(a): return a/np.maximum(norm(a)[...,None],1e-30)

def solve(c,o,p):
    u = unit(p-o)
    w = c-o
    signed_a = cross(u,w)
    a, b, r = np.abs(signed_a), -dot(w,u), norm(w)
    h = b-D
    theta = np.arctan2(a,h)
    alpha = np.arctan2(a,b)
    g = o-D*u  # Internal derivation only; never an observed input.
    valid = (norm(p-o)>1e-9)&(r>D+1e-9)&(h>1e-9)
    return dict(u=u,a=a,b=b,h=h,r=r,theta=theta,alpha=alpha,
                f=1-np.sin(theta),g=g,valid=valid,signed_a=signed_a)

def inside(p):
    return (p[...,0]>=R)&(p[...,0]<=8-R)&(p[...,1]>=R)&(p[...,1]<=4-R)

def point_segment_distance(p,a,b):
    v=b-a
    t=np.clip(dot(p-a,v)/np.maximum(dot(v,v),1e-30),0,1)
    return norm(p-(a+t[...,None]*v))

def segment_distance(a,b,c,d):
    v,w=b-a,d-c
    den=cross(v,w)
    safe=np.where(np.abs(den)>1e-15,den,1)
    t=cross(c-a,w)/safe
    s=cross(c-a,v)/safe
    hit=(np.abs(den)>1e-15)&(t>=0)&(t<=1)&(s>=0)&(s<=1)
    distance=np.minimum.reduce([point_segment_distance(c,a,b),point_segment_distance(d,a,b),
                                point_segment_distance(a,c,d),point_segment_distance(b,c,d)])
    return np.where(hit,0,distance)

def in_arc(angle,start,end):
    return (angle-start)%(2*np.pi)<=(end-start)%(2*np.pi)+1e-10

def segment_arc_distance(a,b,center,radius,start,end):
    v=b-a
    normal_angle=np.arctan2(v[:,1],v[:,0])+np.pi/2
    angles=[np.full(len(a),start),np.full(len(a),end),
            np.arctan2(a[:,1]-center[1],a[:,0]-center[0]),
            np.arctan2(b[:,1]-center[1],b[:,0]-center[0]), normal_angle,normal_angle+np.pi]
    best=np.full(len(a),np.inf)
    for angle in angles:
        q=center+radius*np.stack([np.cos(angle),np.sin(angle)],axis=-1)
        best=np.minimum(best,np.where(in_arc(angle,start,end),point_segment_distance(q,a,b),np.inf))
    # If the segment crosses the circle, zero distance is possible away from extrema.
    vv=dot(v,v); av=dot(a-center,v)
    discriminant=av*av-vv*(dot(a-center,a-center)-radius*radius)
    for sign in [-1,1]:
        t=(-av+sign*np.sqrt(np.maximum(discriminant,0)))/np.maximum(vv,1e-30)
        q=a+t[:,None]*v-center
        hit=(discriminant>=0)&(t>=0)&(t<=1)&in_arc(np.arctan2(q[:,1],q[:,0]),start,end)
        best=np.where(hit,0,best)
    return best

def path_clear(a,b):
    clearance=np.full(len(a),np.inf)
    for line in RAW['lines']:
        c=np.array(line['start'])/UNIT+SHIFT; d=np.array(line['end'])/UNIT+SHIFT
        clearance=np.minimum(clearance,segment_distance(a,b,c,d))
    for arc in RAW['arcs']:
        clearance=np.minimum(clearance,segment_arc_distance(a,b,np.array(arc['center'])/UNIT+SHIFT,
            arc['radius']/UNIT,arc['start'],arc['end']))
    return clearance>=R-1e-8

def capture_endpoint(o,pocket):
    spec=RAW['pockets'][pocket]
    p=REAL_P[pocket]; v=p-o
    # The ray heads at the circle center; polygon clipping finds an earlier lip entry.
    t_circle=1-(spec['radius']/UNIT)/norm(v)
    lip=np.array(spec['lip'])/UNIT+SHIFT
    low=np.zeros(len(o)); high=np.ones(len(o))
    for i in range(len(lip)):
        e=lip[(i+1)%len(lip)]-lip[i]
        base=cross(e,o-lip[i]); change=cross(e,v)
        bound=-base/np.where(np.abs(change)>1e-15,change,1)
        low=np.where(change>1e-15,np.maximum(low,bound),low)
        high=np.where(change< -1e-15,np.minimum(high,bound),high)
        high=np.where((np.abs(change)<=1e-15)&(base<0),-1,high)
    t_lip=np.where(low<=high,low,np.inf)
    t=np.minimum(t_circle,t_lip)
    return o+t[:,None]*v

def feasible(c,o,p,real=False,pocket=0):
    g=solve(c,o,p)
    valid=g['valid']&inside(c)&inside(o)&inside(g['g'])
    if real:
        ids=np.flatnonzero(valid)
        if len(ids):
            valid[ids] &= path_clear(c[ids],g['g'][ids])&path_clear(o[ids],capture_endpoint(o[ids],pocket))
    return valid

def quantize_direction(v,base):
    # Small nonnegative slope library, reflected into all four quadrants.
    angles=np.unique(np.r_[base,np.pi-base,np.pi+base,2*np.pi-base])%(2*np.pi)
    actual=np.arctan2(v[:,1],v[:,0])
    delta=np.angle(np.exp(1j*(actual[:,None]-angles)))
    return angles[np.argmin(np.abs(delta),axis=1)]

def ray_endpoint(g,d):
    candidates=[]
    for axis,limit in [(0,0),(0,8),(1,0),(1,4)]:
        t=(limit-g[:,axis])/np.where(np.abs(d[:,axis])>1e-15,d[:,axis],1e-30)
        candidates.append(np.where(t>1e-8,t,np.inf))
    t=np.min(candidates,axis=0)
    return g+np.where(np.isfinite(t),t,0)[:,None]*d

def predictions(c,o,p):
    q=solve(c,o,p); a,b,h=q['a'],q['b'],q['h']
    valid=q['valid']
    base=np.arctan(np.array([0, .25, 1/3, .5, 2/3, 1, 1.5, 2, 3, 4, np.inf]))
    d1=quantize_direction(o-c,base); d2=quantize_direction(p-o,base)
    dual=np.abs(np.angle(np.exp(1j*(d1-d2))))
    standard=quantize_direction(p-o,np.arctan([0,.5,1,2,np.inf]))
    us=np.stack([np.cos(standard),np.sin(standard)],axis=-1)
    hs=-dot(c-o,us)-D
    ts=np.arctan2(np.abs(cross(us,c-o)),hs)
    nearest=np.argmin(np.abs(q['theta'][:,None]-ANCHORS),axis=1)
    # A finite slope table, with linear interpolation in ratio (not an exact atan).
    ratios=np.array([0,.25,.5,.6,1,8/7,1.8,2,4,8])
    labels=np.array([0,14.5,26.6,30,45,48.6,61,63.4,76,83])
    ratio=np.divide(a,h,out=np.full_like(a,np.inf),where=h>0)
    table=np.deg2rad(np.interp(ratio,ratios,labels))
    # Quarter-diamond ray references are a precomputed template, not a naked-eye oracle.
    n=np.stack([-q['u'][:,1],q['u'][:,0]],axis=-1)
    sign=np.where(q['signed_a']>=0,1,-1)
    ray_angles=[]
    for theta in ANCHORS:
        d=-np.cos(theta)*q['u']+sign[:,None]*np.sin(theta)*n
        endpoint=ray_endpoint(q['g'],d)
        snap=np.round(endpoint*4)/4
        ray_angles.append(np.arctan2(np.abs(cross(q['u'],snap-q['g'])),-dot(q['u'],snap-q['g'])))
    ray_angles=np.stack(ray_angles,axis=-1)
    picked=np.argmin(np.abs(q['theta'][:,None]-ray_angles),axis=1)
    correction=(D/q['r'])*np.sin(q['alpha'])
    # Human version: round alpha to 5 degrees; 10/d times a coarse sine anchor.
    coarse=np.round(np.rad2deg(q['alpha'])/5)*5
    sine_anchors=np.array([0,.25,.5,.75,.875,1.])
    approx_sine=sine_anchors[np.argmin(np.abs(np.sin(np.deg2rad(coarse))[:,None]-sine_anchors),axis=1)]
    human=np.deg2rad(coarse+10/np.maximum(q['r'],.01)*approx_sine)
    raw={
      'alpha':(q['alpha'],valid),
      'dual_directions':(dual,valid&(dual<np.pi/2)),
      'ratio_exact_oracle':(q['theta'],valid),
      'ratio_quarter_grid':(np.arctan2(np.round(a*4)/4,np.round(h*4)/4),valid&(np.round(h*4)>0)),
      'ratio_table10':(table,valid&(ratio<=8)),
      'standard_direction':(ts,valid&(hs>0)),
      'fraction5_oracle':(ANCHORS[nearest],valid),
      'locus_quarter_template':(ANCHORS[picked],valid&inside(q['g'])),
      'first_order_oracle':(q['alpha']+correction,valid),
      'first_order_mental':(human,valid&(human<np.pi/2)),
      'dual_first_order':(dual+D/q['r']*np.sin(dual),valid&(dual+D/q['r']*np.sin(dual)<np.pi/2)),
    }
    return {k:np.where(ok,t,np.nan) for k,(t,ok) in raw.items()}

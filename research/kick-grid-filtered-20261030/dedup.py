"""Conservative geometric deduplication of validated immutable candidate records."""
import math

def point_segment(p,a,b):
    dx,dz=b[0]-a[0],b[1]-a[1]; l=dx*dx+dz*dz
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/l)) if l else 0
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)

def densify(points,step=.01):
    result=[points[0]]
    for a,b in zip(points,points[1:]):
        count=max(1,math.ceil(math.dist(a,b)/step))
        result.extend([[a[j]+(b[j]-a[j])*k/count for j in range(2)] for k in range(1,count+1)])
    return result

def path_close(a,b,diameter):
    # Every segment sample is <=1 cm apart. The 5 mm reserve conservatively
    # covers the interval between samples on the stored piecewise-linear path.
    limit=diameter-.005
    for source,target in [(a,b),(b,a)]:
        for p in densify(source):
            if min(point_segment(p,x,y) for x,y in zip(target,target[1:]))>limit:
                return False
    return True

def same_question(a,b,diameter):
    if a['n']!=b['n'] or a['walls']!=b['walls']:return False
    if math.dist(a['seed']['cue'],b['seed']['cue'])>diameter:return False
    if math.dist(a['target'],b['target'])>diameter:return False
    return path_close([p[1:] for p in a['cueTrack']],[p[1:] for p in b['cueTrack']],diameter)

def rank(row):
    # Selection convention, not a difficulty estimate; never uses perturbation results.
    return (abs(row['offsetR']),row['seed']['v'],row['id'])

def reduce_rows(rows,diameter):
    kept=[];merged=[];comparisons=0
    for row in sorted(rows,key=rank):
        representative=None
        for other in kept:
            comparisons+=1
            if same_question(row,other,diameter):representative=other;break
        if representative:
            merged.append({'removed':row['id'],'representative':representative['id']})
        else:kept.append(row)
    return kept,merged,comparisons

def selftest():
    import copy
    a=dict(id='a',n=1,walls=[0],seed={'cue':[0,0],'v':2},target=[1,0],
           cueTrack=[[0,0,0],[1,.5,.5],[2,1,0]],offsetR=.1)
    near=copy.deepcopy(a);near['id']='near';near['offsetR']=.2
    for p in near['cueTrack']:p[2]+=.01
    near['seed']['cue'][1]+=.01;near['target'][1]+=.01
    detour=copy.deepcopy(a);detour['cueTrack'][1][2]=-.5
    wall=copy.deepcopy(a);wall['walls']=[1]
    far=copy.deepcopy(a);far['target'][0]+=.06
    checks=[same_question(a,a,.05715),same_question(a,near,.05715),
            not same_question(a,detour,.05715),not same_question(a,wall,.05715),
            not same_question(a,far,.05715)]
    keep,merge,_=reduce_rows([near,a],.05715)
    checks.append([r['id'] for r in keep]==['a'] and merge==[{'removed':'near','representative':'a'}])
    assert all(checks),checks
    return {'passed':True,'checks':len(checks),'cases':'identical; nearby; same endpoints/different path; changed wall; distant target; deterministic representative'}

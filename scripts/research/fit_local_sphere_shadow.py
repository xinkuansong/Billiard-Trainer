"""Diagnostic-only local shadow fit. XZ bed, Y up, metres; no product assets.
Fit two elliptical Gaussian lobes to rectangle-light sphere visibility.
Independent, denser light grid validates the fit. A failure is not acceptance.
Run: uv run --with numpy --with scipy python scripts/research/fit_local_sphere_shadow.py OUT
"""
import json,sys
from pathlib import Path
import numpy as np
from scipy.optimize import least_squares
R=.028575

def reference(points,ball,panel,n):
    x=(np.arange(n)+.5)/n*5.08-2.54
    z=(np.arange(n)+.5)/n*1.27-.635+panel
    xx,zz=np.meshgrid(x,z);lights=np.stack([xx.ravel(),np.full(n*n,3.),zz.ravel()],axis=1)
    out=[]
    for chunk in np.array_split(points,max(1,(len(points)+127)//128)):
        rays=lights[None,:,:]-chunk[:,None,:];delta=ball[None,:]-chunk
        length2=np.einsum('bni,bni->bn',rays,rays);dot=np.einsum('bni,bi->bn',rays,delta)
        sphere=np.sum(delta*delta,axis=1)-R*R
        block=(dot>0)&(dot<length2)&(dot*dot>=sphere[:,None]*length2)
        weight=rays[:,:,1]**2/length2**2
        out.extend(np.sum(weight*block,axis=1)/np.sum(weight,axis=1))
    return np.asarray(out)

def predict(q,xy):
    cx,cz,angle,la,lb,lt,amp,mix,power=q
    p=xy-np.array([cx,cz]);c,s=np.cos(angle),np.sin(angle)
    a=p[:,0]*c+p[:,1]*s;b=-p[:,0]*s+p[:,1]*c
    u=(a/np.exp(la))**2+(b/np.exp(lb))**2
    return amp*(mix*np.exp(-.5*np.power(u,power/2))+(1-mix)*np.exp(-.5*u/np.exp(2*lt)))

def main(out):
    out.mkdir(parents=True,exist_ok=True);results=[]
    # Positions include centre and off-centre; height includes rolling and elevated.
    for cx,cz in [(0.,0.),(.8,.4),(-1.15,.52)]:
      for h in [R,.10]:
       ball=np.array([cx,.8+h,cz])
       for panel in [-.635,.635]:
        extent=.32 if h==R else .60
        grid=np.linspace(-extent,extent,35);xx,zz=np.meshgrid(grid,grid);xy=np.stack([xx.ravel(),zz.ravel()],axis=1)
        fitrng=np.random.default_rng(811);xy=np.concatenate([xy,fitrng.uniform(-.08,.08,(1400,2)),np.zeros((1,2))])
        points=np.stack([cx+xy[:,0],np.full(len(xy),.8),cz+xy[:,1]],axis=1)
        target=reference(points,ball,panel,48)
        q=[0,0,0,np.log(.03),np.log(.03),np.log(2),1,.8,4]
        bounds=([-extent,-extent,-np.pi,np.log(.003),np.log(.003),0,0,0,.5],[extent,extent,np.pi,np.log(.5),np.log(.5),np.log(8),1,1,12])
        fitted=least_squares(lambda v:predict(v,xy)-target,q,bounds=bounds,max_nfev=350)
        # Independent receiver locations; include contact point explicitly.
        rng=np.random.default_rng(472);validxy=np.concatenate([rng.uniform(-extent,extent,(800,2)),rng.uniform(-.08,.08,(800,2)),np.zeros((1,2))])
        receivers=np.stack([cx+validxy[:,0],np.full(len(validxy),.8),cz+validxy[:,1]],axis=1)
        truth=reference(receivers,ball,panel,96);coarse=reference(receivers,ball,panel,48)
        predicted=predict(fitted.x,validxy);error=np.abs(predicted-truth)
        active=(truth>.01)|(predicted>.01)
        e=error[active];record={'center':ball.tolist(),'panelZ':panel,'parameters':fitted.x.tolist(),'activeSamples':int(active.sum()),'activeRMSE':float(np.sqrt(np.mean(e*e))),'activeP95':float(np.percentile(e,95)),'max':float(error.max()),'referenceConvergenceP95':float(np.percentile(np.abs(truth-coarse),95)),'contactReference':float(truth[-1]),'contactFit':float(predicted[-1])}
        record['acceptedNumerically']=record['activeRMSE']<=.02 and record['activeP95']<=.05 and record['max']<=.15
        results.append(record);print(json.dumps(record),flush=True)
    (out/'fit.json').write_text(json.dumps({'diagnosticOnly':True,'model':'elliptical super-Gaussian core plus Gaussian tail','thresholds':{'activeRMSE':.02,'activeP95':.05,'max':.15},'cases':results,'accepted':all(x['acceptedNumerically'] for x in results)},indent=2))
if __name__=='__main__':main(Path(sys.argv[1]))

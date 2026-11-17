import math,json
from pathlib import Path

def dot(a,b):return sum(x*y for x,y in zip(a,b))
def sub(a,b):return [x-y for x,y in zip(a,b)]
def norm(a):return math.sqrt(dot(a,a))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def analytic(p,n):
 v=[sub(a,p) for a in [[-1.27,.8,-.635],[-1.27,.8,.635],[1.27,.8,.635],[1.27,.8,-.635]]];cl=[]
 for i,a in enumerate(v):
  b=v[(i+1)%4];da=dot(a,n);db=dot(b,n)
  if da>=0:cl.append(a)
  if (da>=0)!=(db>=0):cl.append([x+(y-x)*da/(da-db) for x,y in zip(a,b)])
 if len(cl)<3:return 0.
 cl=[[x/norm(a) for x in a] for a in cl];s=0.
 for i,a in enumerate(cl):
  b=cl[(i+1)%len(cl)];c=cross(a,b);l=norm(c)
  if l>1e-7:s+=math.atan2(l,dot(a,b))*dot(c,n)/l
 return abs(s)/(2*math.pi)
rows=[]
for name,p,n in [('long-side',[0,.82,-.65],[0,0,1]),('short-side',[-1.285,.82,0],[1,0,0]),('top',[0,.837,-.65],[0,1,0]),('underside',[0,.815,-.64],[0,-1,0])]:
 total=0.;nx=1024;nz=512
 for iz in range(nz):
  dz=(iz+.5)*1.27/nz-.635-p[2];dy=.8-p[1]
  for ix in range(nx):
   dx=(ix+.5)*2.54/nx-1.27-p[0];r2=dx*dx+dy*dy+dz*dz
   total+=max(0,dx*n[0]+dy*n[1]+dz*n[2])*max(0,-dy)/(r2*r2)
 numerical=total*2.54*1.27/(nx*nz*math.pi);exact=analytic(p,n)
 assert abs(numerical-exact)<.005,(name,numerical,exact)
 rows.append({'name':name,'analytic':exact,'quadrature':numerical,'absoluteError':abs(numerical-exact)})
Path('output/rail-bounce-20261117/form-factor-check.json').write_text(json.dumps(rows,indent=2));print(json.dumps(rows,indent=2))

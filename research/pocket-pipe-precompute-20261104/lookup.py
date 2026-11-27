"""Reference consumer. Exact-grid zeros are preserved; unsafe interpolation defers."""
from pathlib import Path
import json,struct,bisect,math,hashlib
class PipeGrid:
 def __init__(self,path):
  path=Path(path);self.meta=json.loads((path/'pipe-grid.json').read_text());self.data=(path/'pipe-grid.bin').read_bytes()
  assert hashlib.sha256(self.data).hexdigest()==self.meta['binarySHA256']
  self.x,self.z=self.meta['x'],self.meta['z'];self.nz=len(self.z)
 def record(self,ix,iz,p):
  index=(ix*self.nz+iz)*6+p;offset,count,flags=struct.unpack_from('<IHH',self.data,index*8)
  windows=[struct.unpack_from('<ff',self.data,self.meta['intervalByteOffset']+(offset+i)*8) for i in range(count)]
  return windows,flags
 def query(self,x,z,p,guarded=True):
  if not 0<=p<6 or not all(map(math.isfinite,[x,z])):return {'status':'invalid'}
  if not self.x[0]<=x<=self.x[-1] or not self.z[0]<=z<=self.z[-1]:return {'status':'outsideDomain'}
  xi=bisect.bisect_left(self.x,x);zi=bisect.bisect_left(self.z,z)
  if xi<len(self.x) and zi<len(self.z) and abs(self.x[xi]-x)<1e-12 and abs(self.z[zi]-z)<1e-12:
   windows,flags=self.record(xi,zi,p)
   if flags&7!=7:return {'status':'requiresExactGeometry'}
   return {'status':'grid','intervals':windows,'width':max((b-a for a,b in windows),default=0)}
  ix=min(len(self.x)-2,max(0,bisect.bisect_right(self.x,x)-1));iz=min(len(self.z)-2,max(0,bisect.bisect_right(self.z,z)-1))
  records=[self.record(ix+dx,iz+dz,p) for dx,dz in [(0,0),(1,0),(0,1),(1,1)]]
  if any(flags!=7 or len(w)!=1 or w[0][1]<=w[0][0] for w,flags in records):return {'status':'requiresExactGeometry'}
  bounds=[w[0] for w,_ in records];widths=[b-a for a,b in bounds]
  spread=max(max(v)-min(v) for v in zip(*bounds));relative=(max(widths)-min(widths))/min(widths)
  policy=self.meta['interpolationPolicy']
  if guarded and (spread>policy['maxEndpointSpreadDegrees'] or relative>policy['maxRelativeWidthSpread']):return {'status':'requiresExactGeometry'}
  u=(x-self.x[ix])/(self.x[ix+1]-self.x[ix]);v=(z-self.z[iz])/(self.z[iz+1]-self.z[iz])
  weights=[(1-u)*(1-v),u*(1-v),(1-u)*v,u*v]
  left,right=[sum(w*row[k] for w,row in zip(weights,bounds)) for k in [0,1]]
  return {'status':'interpolated','intervals':[(left,right)],'width':right-left}
if __name__=='__main__':
 import sys
 grid=PipeGrid(sys.argv[1]);print(json.dumps(grid.query(float(sys.argv[2]),float(sys.argv[3]),int(sys.argv[4])),indent=2))

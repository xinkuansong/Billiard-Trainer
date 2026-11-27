"""Pack all contiguous target-only windows without discarding zero/multiple states."""
from pathlib import Path
import json,struct,hashlib,gzip
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/pocket-pipe-precompute-20261104'
raw=json.loads((OUT/'grid-raw.json').read_text());records=bytearray();bounds=bytearray();isolated={}
for point,options in enumerate(raw['cells']):
 for pocket in range(6):
  option=options[pocket] if options else None
  intervals=option['intervals'] if option else []
  flags=(1 if options else 0)|(2 if option and option['converged'] else 0)|(4 if option and option['closed'] else 0)|(8 if option and option['isolated'] else 0)
  records.extend(struct.pack('<IHH',len(bounds)//8,len(intervals),flags))
  for a,b in intervals:bounds.extend(struct.pack('<ff',a,b))
  if option and option['isolated']:isolated[str(point*6+pocket)]=option['isolated']
data=bytes(records+bounds)
(OUT/'pipe-grid.bin').write_bytes(data)
with (OUT/'pipe-grid.bin.gz').open('wb') as f:
 with gzip.GzipFile(fileobj=f,mode='wb',mtime=0) as g:g.write(data)
geometry=json.loads((OUT/'geometry-manifest.json').read_text())
fingerprint=hashlib.sha256(json.dumps(geometry,sort_keys=True,separators=(',',':')).encode()).hexdigest()
meta={k:raw[k] for k in ['schema','x','z','radius','length','width','pockets']}
meta.update({'coordinateSystem':'SceneKit XZ metres; Y up; landscape +X right, +Z down','angleUnit':'degrees',
 'angleReference':'atan2(pocket.z-target.z,pocket.x-target.x); bounds are signed offsets from this direction',
 'scope':'target ball only; clean real-radius pipe up to capture; no cue, other balls, force, spin, jaw rebound or score',
 'positionDomain':'real-ball-radius inset playfield rectangle, excluding pocket capture; not exterior lip area',
 'recordIndex':'((ix * nz) + iz) * 6 + pocketIndex','recordFormat':'little-endian uint32 intervalOffset, uint16 intervalCount, uint16 flags',
 'intervalFormat':'little-endian float32 leftDegrees, float32 rightDegrees; 8 bytes per interval',
 'recordCount':len(records)//8,'intervalByteOffset':len(records),'intervalCount':len(bounds)//8,
 'flags':{'1':'valid target position','2':'two-resolution convergence','4':'both scan ends closed','8':'isolated tangent directions present'},
 'isolatedDirections':isolated,'geometryFingerprint':fingerprint,'geometrySources':geometry,
 'binarySHA256':hashlib.sha256(data).hexdigest(),'binaryBytes':len(data),
 'interpolationPolicy':{'requires':'four valid, converged, closed, single positive windows; no isolated directions',
 'maxEndpointSpreadDegrees':0.1,'maxRelativeWidthSpread':0.10,
 'otherwise':'request exact geometry; never interpolate across zero/open/multiple/invalid states'},
 'angularScanDegrees':[0.05,0.025],'refinementScanDegrees':[0.005,0.0025,0.001,0.0005],
 'generatorSourcesSHA256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in Path(__file__).resolve().parent.glob('*.py')} | {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in Path(__file__).resolve().parent.glob('*.swift')},
 'boundaryConvergenceDegrees':0.001,'zeroMeaning':'no positive clean interval at the stated resolution; not proof against jaw-assisted pots'})
(OUT/'pipe-grid.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:meta[k] for k in ['recordCount','intervalCount','binaryBytes','binarySHA256']},indent=2))

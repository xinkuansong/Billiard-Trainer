"""Package the already measured field verbatim; no quantization or image conversion."""
from pathlib import Path
import hashlib,json,struct
root=Path(__file__).resolve().parents[3]
source=root/'output/render-activity-20261113/c1-static-field-compact/scene-1400'
target=root/'QiuJi/Resources/StaticClothIrradiance-v1.bin'
fields=[(source/f'field-{i}.bin').read_bytes() for i in range(2)]
assert all(len(f)==64*32*16*16 for f in fields)
assert all(abs(x)<100 for f in fields for (x,) in struct.iter_unpack('<f',f))
data=b''.join(fields)
target.write_bytes(data)
manifest={'asset':str(target.relative_to(root)),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'dimensions':[64,32,16],'format':'two consecutive RGBA32Float 3D textures, x fastest then z then y; little endian','domain':{'x':[-1.6,1.6],'z':[-.95,.95],'y':[.65,.9]},'sourceFiles':[{ 'path':str((source/f'field-{i}.bin').relative_to(root)), 'sha256':hashlib.sha256(f).hexdigest()} for i,f in enumerate(fields)],'generatorSHA256':hashlib.sha256((source.parent/'generate.metal').read_bytes()).hexdigest()}
(root/'tasks/render-activity-20261113/C1-field-asset.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(manifest['sha256'])

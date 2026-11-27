import json,re,struct
from pathlib import Path
p=Path('output/plan-three-implementation-20261101/pad-r4-attachments');rows=[]
attachments=[a for row in json.loads((p/'manifest.json').read_text()) for a in row['attachments']]
for a in attachments:
 f=p/a['exportedFileName'];name=a['suggestedHumanReadableName']
 if f.suffix!='.png':continue
 b=f.read_bytes();w,h=struct.unpack('>II',b[16:24]);i=8;orientation=1
 while i<len(b):
  n=struct.unpack('>I',b[i:i+4])[0]
  if b[i+4:i+8]==b'eXIf':
   e=b[i+8:i+8+n];endian='>' if e[:2]==b'MM' else '<';off=struct.unpack(endian+'I',e[4:8])[0]
   for k in range(struct.unpack(endian+'H',e[off:off+2])[0]):
    q=off+2+12*k;tag,kind,count=struct.unpack(endian+'HHI',e[q:q+8])
    if tag==274:orientation=struct.unpack(endian+'H',e[q+8:q+10])[0]
  i+=n+12
 display=(h,w) if orientation in [5,6,7,8] else (w,h)
 prefix=name.split('_0_')[0];hier=next(x for x in attachments if x['suggestedHumanReadableName'].startswith(prefix+'-hierarchy_'))
 t=(p/hier['exportedFileName']).read_text();m=re.search(r'Window \(Main\).*?\{\{[\d.]+, [\d.]+\}, \{([\d.]+), ([\d.]+)\}\}',t)
 window=tuple(float(v) for v in m.groups());assert display[0]/display[1]==window[0]/window[1]
 if 'pad-portrait' in prefix:assert window[1]>window[0]
 if 'landscape-return' in prefix:assert window[0]>window[1]
 rows.append(dict(name=prefix,file=f.name,pngStorage=[w,h],orientation=orientation,display=display,actualWindow=window))
(p.parent/'pad-image-dimensions.json').write_text(json.dumps(rows,indent=2));print(json.dumps(rows,indent=2))

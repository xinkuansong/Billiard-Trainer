#!/usr/bin/env python3
"""Lossless USDZ constant PNG reduction with pixel and archive proofs.

prepare requires Pillow; pack requires pxr (e.g. Blender's Python).
The source is never changed. Review the proofs and render comparisons before
replacing a shipped asset; update ModelAssetTrial asset SHA when accepting it.
"""
from pathlib import Path
import argparse, hashlib, io, json, struct, zipfile, zlib

parser = argparse.ArgumentParser(description=__doc__)
sub = parser.add_subparsers(dest='command', required=True)
p = sub.add_parser('prepare')
p.add_argument('source', type=Path)
p.add_argument('workdir', type=Path)
p.add_argument('--expected-changes', type=int)
p = sub.add_parser('pack')
p.add_argument('workdir', type=Path)
p.add_argument('target', type=Path)
args = parser.parse_args()
out = args.workdir.resolve()
work = out / 'unpacked'
if args.command == 'prepare':
 from PIL import Image
 out.mkdir(parents=True, exist_ok=True)
 work.mkdir(exist_ok=True)
 sha=lambda b:hashlib.sha256(b).hexdigest()
 report=[]
 with zipfile.ZipFile(args.source) as z:
  order=z.namelist()
  for name in order:
   if Path(name).is_absolute() or '..' in Path(name).parts:
    raise ValueError(f'Unsafe archive member: {name}')
   data=z.read(name); result=data; row={'name':name,'before_sha256':sha(data)}
   if name.endswith('.png'):
    image=Image.open(io.BytesIO(data)); extrema=image.getextrema()
    if image.mode in ('RGB', 'RGBA') and image.size==(2048,2048) and all(lo==hi for lo,hi in extrema):
     assert image.mode in ['RGB','RGBA']
     # Keep ALL ancillary chunks (including ICC/gamma/chromaticity/sRGB),
     # bit depth, colour type and channel bytes. Only dimensions/IDAT change.
     chunks=[]; cursor=8
     while cursor<len(data):
      n=struct.unpack('>I',data[cursor:cursor+4])[0]; kind=data[cursor+4:cursor+8]; payload=data[cursor+8:cursor+8+n]
      chunks.append((kind,payload));cursor+=12+n
     ihdr=chunks[0][1]; assert ihdr[8]==8 and ihdr[9] in (2,6) and ihdr[12]==0
     def chunk(kind,payload): return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
     result=b'\x89PNG\r\n\x1a\n'; emitted=False
     pixel=image.getpixel((0,0))
     for kind,payload in chunks:
      if kind==b'IHDR':payload=struct.pack('>II',1,1)+payload[8:]
      if kind==b'IDAT':
       if emitted:continue
       payload=zlib.compress(b'\x00'+bytes(pixel));emitted=True
      result+=chunk(kind,payload)
     reduced=Image.open(io.BytesIO(result));assert reduced.size==(1,1) and reduced.getpixel((0,0))==pixel
     assert {k:v for k,v in reduced.info.items() if k in ['icc_profile','gamma','srgb','chromaticity']}=={k:v for k,v in image.info.items() if k in ['icc_profile','gamma','srgb','chromaticity']}
     row.update(original_size=image.size,pixel=pixel,reduced_size=[1,1],mode=image.mode)
   target=work/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(result)
   row['after_sha256']=sha(result);report.append(row)
 changed = sum(x['before_sha256'] != x['after_sha256'] for x in report)
 if args.expected_changes is not None: assert changed == args.expected_changes
 (out/'member-order.json').write_text(json.dumps(order))
 (out/'pixel-proof.json').write_text(json.dumps(report,indent=2))
 print(f'Prepared {changed} constant PNGs; all other members unchanged')
else:
 from pxr import Usd
 target = args.target.resolve()
 if target.exists(): raise SystemExit('Refusing to replace an existing output; choose a fresh target')
 order=json.loads((out/'member-order.json').read_text())
 with Usd.ZipFileWriter.CreateNew(str(target)) as writer:
  for name in order: assert writer.AddFile(str(work/name),name)==name
 assert Usd.Stage.Open(str(target))
 with zipfile.ZipFile(target) as z:
  assert z.namelist()==order
  with target.open('rb') as f:
   for i in z.infolist():
    assert i.compress_type==zipfile.ZIP_STORED
    f.seek(i.header_offset+26);n,e=struct.unpack('<HH',f.read(4));assert (i.header_offset+30+n+e)%64==0
    assert z.read(i.filename)==(work/i.filename).read_bytes()
 proof={'writer':'OpenUSD '+str(Usd.GetVersion()),'asset':target.name,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'members':len(order),'alignment_bytes':64,'usd_bytes_unchanged':all(x['before_sha256']==x['after_sha256'] for x in json.loads((out/'pixel-proof.json').read_text()) if not x['name'].endswith('.png'))}
 (out/'package-proof.json').write_text(json.dumps(proof,indent=2));print(proof)

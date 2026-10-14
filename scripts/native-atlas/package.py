#!/usr/bin/env python3
"""Package explicitly reviewed native captures for the single Figma writer."""
import argparse,base64,hashlib,json
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('--review',type=Path,required=True);p.add_argument('--plugin',type=Path,required=True);p.add_argument('--batch',required=True)
p.add_argument('--archive-only',action='store_true',help='Prepare an immutable import package without replacing the active Figma plugin or its pending receipt')
a=p.parse_args()
review=json.loads(a.review.read_text());entries=[]
for item in review['images']:
    if item['status']!='VALIDATED':continue
    source=Path(item['path']);data=source.read_bytes();digest=hashlib.sha256(data).hexdigest()
    if digest!=item['sha256']:raise ValueError('Evidence changed '+str(source))
    with Image.open(source) as im:im.load();w,h=im.size
    if [w,h]!=item['pixels']:raise ValueError('Dimensions changed')
    entry={k:v for k,v in item.items() if k not in ['path','status','pixels','note']}
    entry.update(pixelWidth=w,pixelHeight=h,png=base64.b64encode(data).decode())
    entries.append(entry)
if not entries:raise ValueError('No validated captures')
a.plugin.mkdir(parents=True,exist_ok=True)
archive=a.plugin.parent/'packages'/a.batch
archive.mkdir(parents=True,exist_ok=False)
pack={'batch':a.batch,'entries':entries};code='const PACK='+json.dumps(pack,ensure_ascii=False)+';\n'+Path('scripts/native-atlas/figma/import.js').read_text()
(archive/'code.js').write_text(code)
(archive/'manifest.json').write_bytes(Path('scripts/native-atlas/figma/manifest.json').read_bytes())
if not a.archive_only:
    runtime=a.plugin/'code.js'
    if runtime.is_symlink():runtime.unlink()
    runtime.write_text(code)
    (a.plugin/'manifest.json').write_bytes((archive/'manifest.json').read_bytes())
receipt={'batch':a.batch,'review':str(a.review.resolve()),'count':len(entries),'entries':[{k:v for k,v in e.items() if k!='png'} for e in entries]}
if not a.archive_only:
    (a.plugin/(a.batch+'-package.json')).write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
(archive/'package.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'batch':a.batch,'images':len(entries),'plugin':str(a.plugin.resolve()),'archiveOnly':a.archive_only,'archive':str(archive.resolve())},ensure_ascii=False))

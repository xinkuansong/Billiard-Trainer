"""Render frozen report with the installed macOS font; computation stays unchanged."""
from pathlib import Path
import hashlib,json,time
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
source=HERE/'report.py';manifest=json.loads((OUT/'manifest.json').read_text())
assert hashlib.sha256(source.read_bytes()).hexdigest()==manifest['hashes'][str(source.relative_to(ROOT))]
font=Path('/Library/Fonts/Arial Unicode.ttf');assert font.exists()
code=source.read_text().replace('/System/Library/Fonts/PingFang.ttc',str(font))
exec(compile(code,str(source),'exec'),{'__file__':str(source),'__name__':'__main__'})
(OUT/'report-recovery.json').write_text(json.dumps({'resolvedAt':time.time(),'cause':'original report used unavailable /System/Library/Fonts/PingFang.ttc','fix':'render identical frozen report with installed Arial Unicode font','originalFailurePreserved':'failure.json and failures/','dataAndManifestUnchanged':True,'reportGenerated':True},indent=2))

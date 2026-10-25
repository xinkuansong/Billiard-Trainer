from pathlib import Path
import json, hashlib

OUT=Path(__file__).resolve().parent
VIS=Path('/Users/song/.codex/visualizations/2026/10/22/01a16335-32e9-7cb2-a527-a51271a95134/separation-score-examples.html')
data=json.loads((OUT/'examples.json').read_text())
assert data['sample']['geometry']['width']>1.26
def round_tree(v):
    if isinstance(v,float): return round(v,7)
    if isinstance(v,list): return [round_tree(a) for a in v]
    if isinstance(v,dict): return {k:round_tree(a) for k,a in v.items()}
    return v
template=(OUT/'visual-template.html').read_text()
assert template.count('__DATA__')==1
html=template.replace('__DATA__',json.dumps(round_tree(data),ensure_ascii=False,separators=(',',':')))
assert len(html.encode())<1000000
assert '\\"' not in html and '<html' not in html.lower()
VIS.parent.mkdir(parents=True,exist_ok=True)
VIS.write_text(html)
(OUT/'visual-output.json').write_text(json.dumps({'path':str(VIS),'bytes':VIS.stat().st_size,'sha256':hashlib.sha256(VIS.read_bytes()).hexdigest()},indent=2))
print(str(VIS),VIS.stat().st_size)

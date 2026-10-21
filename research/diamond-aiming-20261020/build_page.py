"""Produce one offline HTML file, retaining editable source modules."""
from pathlib import Path
import json
P=Path(__file__).resolve().parent
html=(P/'page.html').read_text()
data='const TABLE_GEOMETRY='+json.dumps(json.loads((P/'geometry.json').read_text()),ensure_ascii=False)+';\n'
data+='const STATS='+json.dumps(json.loads((P/'results/summary.json').read_text()),ensure_ascii=False)+';'
html=html.replace('/*__DATA__*/',data).replace('/*__GEOMETRY__*/',(P/'geometry.js').read_text()).replace('/*__APP__*/',(P/'app.js').read_text())
assert '/*__' not in html
(P/'index.html').write_text(html)
print('Built offline index.html:',len(html.encode()),'bytes')

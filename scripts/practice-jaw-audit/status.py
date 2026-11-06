"""Print committed results; staged candidates and final App verification stay distinct."""
from collections import Counter
import json
from pathlib import Path
import sys

work=Path(sys.argv[1])
for family,expected in [('bank',21569),('kball',11458),('two',677488),('sep',782528*4)]:
    root=work
    if family in ('bank','kball','two'):
        while (root/'refined'/(family+'-stage.json')).exists():
            root=root/'refined'
    stage=root/(family+'-stage.json')
    if stage.exists():
        counts=json.loads(stage.read_bytes())['counts']
    else:
        ledger=(root/'sep' if family=='sep' else root)/'rows'
        counts=Counter()
        for path in ledger.glob(family+'-*.json'):
            counts.update(row.get('state',row.get('result')) for row in json.loads(path.read_bytes()))
    print(family,sum(counts.values()),'/',expected,dict(counts))
    report=root/(family+'-app-replay.json')
    if report.exists():print('App',report.read_text()[:200])

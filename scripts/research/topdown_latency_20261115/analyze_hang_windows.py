"""Extract concrete original-device hang windows without equating weights to end-to-end latency."""
from pathlib import Path
import json,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[3]/'output/topdown-latency-device-20261115'
report=[]
for name in ['open-01','open-02-standalone']:
 p=root/name;rows=json.loads((p/'symbolized-app-samples.json').read_text())
 for h in ET.parse(p/'hangs.xml').findall('.//row'):
  start=float(h[0].text)/1e9;duration=float(h[1].text)/1e9
  if duration>3:continue # End-clipped severe hang remains excluded, not silently reclassified.
  selected=[x for x in rows if start<=x['time']<=start+duration]
  main=[x for x in selected if 'Main Thread' in x['thread']]
  pipeline=[x for x in selected if any('newRenderPipelineState' in s for s in x['stack'])]
  compiler=[x for x in selected if any('MTLCompilerScheduler' in s for s in x['stack'])]
  state={'trace':name,'startSeconds':start,'hangDurationMs':duration*1000,'endSeconds':start+duration,
   'mainSamples':main,'pipelineSamples':pipeline,'compilerSamples':compiler,
   'limits':'Potential-hang interval; individual sample weight is not a button-to-first-frame measurement. Concurrent waits do not reveal mutex owner identity.'}
  report.append(state)
(root/'specific-hang-windows.json').write_text(json.dumps(report,indent=2))
for r in report:
 print(r['trace'],round(r['hangDurationMs'],2),'ms main',len(r['mainSamples']),'pipeline',len(r['pipelineSamples']),'compiler',len(r['compilerSamples']))

from pathlib import Path
from PIL import Image,ImageChops
import json,shutil,sys
attachments=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(exist_ok=True,parents=True)
rows=[a for t in json.loads((attachments/'manifest.json').read_text()) for a in t['attachments']]
report=[]
for view in ['low','oblique','detail','pocket','top']:
 prefix='rail-integrated-'+view+'_'
 row=next(r for r in rows if r['suggestedHumanReadableName'].startswith(prefix))
 dst=out/('rail-integrated-'+view+'.png');shutil.copy2(attachments/row['exportedFileName'],dst)
 old=Path('output/rail-bed-shadow-20261117')/('rail-bed-shadow-'+view+'-C-bedShadow.png')
 current=Image.open(dst).convert('RGB');previous=Image.open(old).convert('RGB')
 delta=ImageChops.difference(current,previous)
 rowA=next(r for r in rows if r['suggestedHumanReadableName'].startswith('rail-bed-shadow-'+view+'-A-original_'))
 newA=Image.open(attachments/rowA['exportedFileName']).convert('RGB')
 oldA=Image.open(Path('output/rail-bed-shadow-20261117')/('rail-bed-shadow-'+view+'-A-original.png')).convert('RGB')
 effectMismatch=0;effectMaximum=0
 for a,c,aa,cc in zip(newA.getdata(),current.getdata(),oldA.getdata(),previous.getdata()):
  error=max(abs((c[i]-a[i])-(cc[i]-aa[i])) for i in range(3))
  if error:effectMismatch+=1;effectMaximum=max(effectMaximum,error)
 report.append({'view':view,'wholeHistoricalScreenshotExact':delta.getbbox() is None,'maximumHistoricalChannelDelta':max(v[1] for v in delta.getextrema()),'effectDeltaMismatchPixels':effectMismatch,'maximumEffectDeltaDifference':effectMaximum})
(out/'approved-preview-audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))

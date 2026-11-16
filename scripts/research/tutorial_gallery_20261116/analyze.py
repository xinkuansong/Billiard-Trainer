import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--work',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
copy=a.work/'readable.xcresult'
subprocess.run(['cp','-cR',str(a.input),str(copy)],check=True)
for command,name in [('summary','summary.json'),('tests','tests.json')]:
 with (a.out/name).open('w') as out:subprocess.run(['xcrun','xcresulttool','get','test-results',command,'--path',str(copy),'--format','json'],stdout=out,check=True)
subprocess.run(['xcrun','xcresulttool','export','attachments','--path',str(copy),'--output-path',str(a.out/'shots')],check=True)
j=json.loads((a.out/'summary.json').read_text());print(json.dumps({k:j.get(k) for k in ['result','passedTests','failedTests','skippedTests','totalTestCount','testFailures']},ensure_ascii=False))

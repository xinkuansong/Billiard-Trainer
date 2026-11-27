#!/usr/bin/env python3
"""Run a single selected test batch under the existing fleet lease; retain real hold screenshots."""
import pathlib,subprocess,sys,threading,time,re,json
ROOT=pathlib.Path(__file__).resolve().parents[3]
RUN=ROOT/'output/local-test-runs/f5bfed55156343e0b43b776e8c04f50a'
if sys.argv[1]!='--leased':
 name,role,selector,*rest=sys.argv[1:]
 command=['python3','scripts/simulator_fleet.py','run','--role',role,'--task','v73-feedback-'+name,'--','python3','scripts/spatial-quiz/with-booted.py','{udid}','python3',str(pathlib.Path(__file__).resolve()),'--leased','{udid}',name,selector,*rest]
 sys.exit(subprocess.call(command,cwd=ROOT))
udid,name,selector,*rest=sys.argv[2:];action=rest[0] if rest else 'test'
evidence=RUN/'evidence';raw=evidence/(name+'.log');result=evidence/(name+'.xcresult');shots=evidence/(name+'-holds');shots.mkdir(exist_ok=False)
assert not result.exists()
selectors=selector.split(',');assert all(s.startswith(('CuePhysTests/','CuePhysUITests/')) for s in selectors)
command=['make','-f','scripts/Makefile','_test',f'TEST_DESTINATION=platform=iOS Simulator,id={udid}',f'BUILD_DIR={RUN}/work',f'DERIVED_DATA={RUN}/work/DerivedData',f'TEST_LOG={raw}',f'TEST_JUNIT={evidence}/{name}.xml',f'TEST_RESULT_BUNDLE={result}','TEST_SELECTOR='+' '.join('-only-testing:'+s for s in selectors),'TEST_ACTION='+action,'TEST_CODE_COVERAGE=NO','TEST_BUILD_SETTINGS=-collect-test-diagnostics never']
captures=[];threads=[]
def capture(tag):
 for n in range(2):
  time.sleep(2)
  out=shots/(tag+f'-{n}.png')
  r=subprocess.run(['xcrun','simctl','io',udid,'screenshot',str(out)],capture_output=True,text=True)
  captures.append({'tag':tag,'frame':n,'code':r.returncode,'file':str(out.relative_to(ROOT)),'stderr':r.stderr})
with (evidence/(name+'-driver.log')).open('w') as log:
 proc=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
 stream=None
 while proc.poll() is None:
  if stream is None and raw.exists():stream=raw.open()
  if stream:
   for line in stream:
    match=re.search(r'SPATIAL_CLOSEUP_HOLD ([A-Za-z]+-(?:enabled|disabled))',line)
    if match:
     t=threading.Thread(target=capture,args=(match[1],));threads.append(t);t.start()
  time.sleep(.2)
 for t in threads:t.join()
 (shots/'captures.json').write_text(json.dumps(captures,indent=2))
 print('RESULT',name,proc.returncode,'captures',len(captures),'log',raw,flush=True)
 sys.exit(proc.returncode)

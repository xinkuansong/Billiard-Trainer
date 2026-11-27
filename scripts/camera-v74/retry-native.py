#!/usr/bin/env python3
"""Reuse this task's protected build under the queue worker lock and device lease."""
import os,sys,subprocess,json,fcntl,signal
from pathlib import Path
if sys.argv[1]=='--leased':
 job=Path(sys.argv[2]);out=Path(sys.argv[3]);udid=sys.argv[4];selectors=sys.argv[5:]
 source=job/'source';scripts=source/'scripts'
 subprocess.run(['xcrun','simctl','boot',udid],capture_output=True)
 subprocess.run(['xcrun','simctl','bootstatus',udid,'-b'],check=True)
 devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']))['devices']
 runtime,device=next((runtime,device) for runtime,rows in devices.items() for device in rows if device['udid']==udid)
 runtimes=json.loads(subprocess.check_output(['xcrun','simctl','list','runtimes','--json']))['runtimes']
 (out/'device.json').write_text(json.dumps({'device':device,'runtime':next(r for r in runtimes if r['identifier']==runtime)}))
 motionTool=os.environ.get('V74_REDUCE_MOTION_TOOL')
 oldMotion=None
 if motionTool:
  def motion(value=None):
   command=['xcrun','simctl','spawn',udid,motionTool]+([] if value is None else [str(int(value))])
   return json.loads(subprocess.check_output(command,text=True))
  oldMotion=motion()['reduceMotion']
  enabled=motion(True)
  (out/'reduce-motion.json').write_text(json.dumps({'before':oldMotion,'active':enabled}))
 video=None
 if os.environ.get('V74_RECORD_VIDEO','1') != '0':
  videoLog=(out/'video.log').open('w')
  video=subprocess.Popen(['xcrun','simctl','io',udid,'recordVideo',str(out/'native.mp4')],stdout=videoLog,stderr=videoLog)
 cmd=['make','-f',str(scripts/'Makefile'),'test','TEST_ACTION=test-without-building',
      'TEST_DESTINATION=platform=iOS Simulator,id='+udid,'TEST_CODE_COVERAGE=NO',
      'BUILD_DIR='+str(job/'build'),'DERIVED_DATA='+str(job/'build/DerivedData'),
      'TEST_LOG='+str(out/'tests.log'),'TEST_JUNIT='+str(out/'tests.xml'),'SIM_TEST_GUARD=',
      'TEST_BUILD_SETTINGS=CODE_SIGNING_ALLOWED=NO -resultBundlePath '+str(out/'tests.xcresult'),
      'TEST_SELECTOR='+' '.join('-only-testing:'+x for x in selectors)]
 (out/'test-command.json').write_text(json.dumps(cmd))
 try:
  with (out/'make.log').open('w') as log:result=subprocess.run(cmd,cwd=source,stdout=log,stderr=subprocess.STDOUT)
 finally:
  if video:
   video.send_signal(signal.SIGINT)
   try:video.wait(timeout=20)
   except subprocess.TimeoutExpired:video.terminate();video.wait()
  if motionTool:
   (out/'reduce-motion-restored.json').write_text(json.dumps(motion(oldMotion)))
 (out/'result.json').write_text(json.dumps({'exitCode':result.returncode,'sourceJob':job.name,'udid':udid,'selectors':selectors}))
 sys.exit(result.returncode)
job=Path(sys.argv[1]);out=Path(sys.argv[2]);udid=sys.argv[3];selectors=sys.argv[4:]
out.mkdir(parents=True,exist_ok=False)
queue=job.parent.parent
lock=open(queue/'worker.lock','a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
source=job/'source';scripts=source/'scripts'
device=['--udid',udid]
if udid.startswith('temporary,'):
 _,deviceType,runtime=udid.split(',')
 device=['--temporary','--type',deviceType,'--runtime',runtime,'--evidence',str(out/'result.json')]
 udid='{udid}'
cmd=['python3',str(scripts/'simulator_lifecycle.py'),'run','--task',out.name,*device,'--',
     'python3',__file__,'--leased',str(job),str(out),udid,*selectors]
# Outer branch is split below before locking recursively.
(out/'command.json').write_text(json.dumps(cmd))
with (out/'lifecycle.log').open('w') as log:r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT)
sys.exit(r.returncode)

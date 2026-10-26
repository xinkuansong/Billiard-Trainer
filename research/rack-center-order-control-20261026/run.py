from pathlib import Path
import importlib.util,sys,json,subprocess,os,time,traceback
import build
ROOT,OUT=build.ROOT,build.OUT
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('old_worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(name,value):(OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2))
def main(uid):
 binary=build.build();protocol=json.loads((OUT/'protocol.json').read_text());boot=False;w=None;success=False;code=None
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  w=mod.Worker(uid,binary,OUT);write('metadata.json',w.ready);rows=[]
  for rack in protocol['racks']:
   for rev in [False,True]:
    inp=dict(id=f"{rack['rackID']}-{rev}",n=15,seed=rack['seed'],rackID=rack['rackID'],split='diagnostic',position='center',x=w.ready['length']/4,z=0,power=9.75,reverseRegistration=rev)
    r=w.run(inp);assert r['status']=='settled';rows.append(r)
  write('raw.json',rows);success=True
 finally:
  if w:code=w.close()
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,workerExitCode=code,shutdownExitCode=None if shut is None else shut.returncode,device=uid,work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE']))
if __name__=='__main__':main(sys.argv[1])

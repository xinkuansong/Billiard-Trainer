#!/usr/bin/env python3
"""Eight persistent native solver processes, atomic compressed shards, resumable audit."""
from pathlib import Path
import signal,collections,concurrent.futures,gzip,hashlib,json,os,queue,select,shutil,struct,subprocess,sys,threading,time,traceback

ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/two-ball-strike-sampled100-20261024';APP=HERE/'Worker.app/Worker'
LOCK=threading.Lock();LIVE={};STOP=threading.Event()
def write(path,data):
    tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2));tmp.replace(path)
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(2**20),b''):h.update(b)
    return h.hexdigest()
def f32(x):return struct.unpack('f',struct.pack('f',x))[0]
def checked(row,board,cs):
    assert row['id']==board['id'] and len(row['rows'])==len(cs)
    for trial,c in zip(row['rows'],cs):
        assert trial['comboIndex']==c['comboIndex']
        for k in ['spinX','spinY','velocity']:assert trial[k]==f32(c[k])
        assert trial['parameterStatus'] in ['legal','illegal','undetermined']
        assert trial['targetPottedSelected']==(trial['targetActualPocket']==f"pocket_{board['pocket']}")
        assert trial['cueCushionTotal']==sum(e['kind']=='cushion' and e['ball']=='cueBall' for e in trial['events'])
        assert ('cueStop' in trial)==trial['cueStopValid']
        assert not ('cuePath' in trial or 'recorder' in trial)
        if trial['parameterStatus']=='illegal':assert trial['status']=='illegal_parameters' and not trial['usableForPositionMatch']
        if trial['usableForPositionMatch']:
            assert trial['parameterStatus']=='legal' and trial['targetPottedSelected'] and not trial['cuePocketed'] and trial['cueStopValid'] and trial['resolved']
class Worker:
    def __init__(self,uid,index):
        self.index=index;self.log=(OUT/'logs'/f'worker-{index}.log').open('a')
        self.p=subprocess.Popen(['xcrun','simctl','spawn',uid,str(APP)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.log,text=True,bufsize=1)
        try:self.ready=self.receive('READY',120)
        except Exception:self.close();raise
        self.pid=self.ready['pid'];print('worker',index,'native pid',self.pid,flush=True)
        write(OUT/'logs'/f'worker-{index}-metadata.json',self.ready)
    def receive(self,prefix,timeout):
        deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            ready,_,_=select.select([self.p.stdout],[],[],max(0,deadline-time.monotonic()))
            if not ready:break
            line=self.p.stdout.readline()
            if not line:raise RuntimeError(f'worker {self.index} exited {self.p.poll()}')
            if line.startswith(prefix+'\t'):return json.loads(line.split('\t',1)[1])
            if line.startswith('ERROR\t'):raise RuntimeError(line)
            self.log.write(line);self.log.flush()
        raise TimeoutError(f'worker {self.index} response timeout')
    def run(self,board,cs):
        self.p.stdin.write(json.dumps({'board':board,'combinations':cs},separators=(',',':'))+'\n');self.p.stdin.flush()
        result=self.receive('RESULT',180);checked(result,board,cs);return result
    def close(self):
        if hasattr(self,'p'):
            if self.p.stdin:
                try:self.p.stdin.close()
                except OSError:pass
            try:self.p.wait(timeout=15)
            except subprocess.TimeoutExpired:self.p.terminate();self.p.wait(timeout=15)
        self.log.close()

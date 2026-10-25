import subprocess,time,threading,json,statistics
class MemoryMonitor:
 def __init__(self,native,control,out):
  self.native=set(native);self.control=set(control);self.out=out;self.rows=[];self.errors=[];self.event=threading.Event();self.thread=threading.Thread(target=self.sample,daemon=True)
 def start(self):self.thread.start()
 def sample(self):
  t0=time.monotonic();ids=self.native|self.control
  while not self.event.is_set():
   begin=time.monotonic()
   try:
    s=subprocess.check_output(['ps','-o','pid=,rss=','-p',','.join(map(str,sorted(ids)))],text=True)
    data={int(a):int(b)*1024 for a,b in (l.split() for l in s.splitlines())}
    self.rows.append(dict(seconds=time.monotonic()-t0,nativeRSSBytes=sum(data.get(p,0) for p in self.native),controlRSSBytes=sum(data.get(p,0) for p in self.control),totalRSSBytes=sum(data.values()),nativeProcessesObserved=len(self.native&data.keys()),perPID=data))
   except Exception as e:self.errors.append(repr(e))
   self.event.wait(max(0,1.0-(time.monotonic()-begin)))
 def stop(self):
  self.event.set();self.thread.join()
  if not self.rows:raise RuntimeError('No memory samples')
  peak=max(self.rows,key=lambda x:x['totalRSSBytes'])
  summary=dict(method='ps RSS simultaneous sum; 1s target interval; native workers + Python controller/compression + simctl wrappers; excludes shared CoreSimulator services and unrelated apps; RSS may count shared pages multiple times; sampled peak is not exact OS high-water mark',samples=len(self.rows),errors=self.errors,peakTotalRSSBytes=peak['totalRSSBytes'],peakNativeRSSBytes=max(r['nativeRSSBytes'] for r in self.rows),peakControlRSSBytes=max(r['controlRSSBytes'] for r in self.rows),peakSample=peak,maxIntervalSeconds=max((b['seconds']-a['seconds'] for a,b in zip(self.rows,self.rows[1:])),default=0))
  (self.out/'memory.json').write_text(json.dumps(summary,indent=2))
  (self.out/'memory-samples.json').write_text(json.dumps(self.rows,separators=(',',':')))

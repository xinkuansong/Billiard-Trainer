"""Read-only, section/symbol comparison of the two preserved device binaries."""
import bisect,json,struct,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[3]/'output/topdown-latency-device-20261115'
class MachO:
 def __init__(self,p):
  self.b=p.read_bytes();self.sections=[];self.syms=[];off=32
  assert struct.unpack_from('<I',self.b)[0]==0xfeedfacf
  for _ in range(struct.unpack_from('<I',self.b,16)[0]):
   cmd,size=struct.unpack_from('<II',self.b,off)
   if cmd==0x19:
    for j in range(struct.unpack_from('<I',self.b,off+64)[0]):
     q=off+72+j*80;name,seg,addr,n,fo=struct.unpack_from('<16s16sQQI',self.b,q)
     self.sections.append({'name':name.rstrip(b'\0').decode(),'segment':seg.rstrip(b'\0').decode(),'addr':addr,'size':n,'offset':fo})
   if cmd==2:self.symoff,self.nsyms,self.stroff,self.strsize=struct.unpack_from('<IIII',self.b,off+8)
   off+=size
  for j in range(self.nsyms):
   st,t,se,desc,v=struct.unpack_from('<IBBHQ',self.b,self.symoff+j*16)
   name=self.b[self.stroff+st:self.b.index(b'\0',self.stroff+st)].decode('utf8','replace')
   if t&0xe==0xe and se:self.syms.append({'name':name,'addr':v,'section':se})
  self.byname={s['name']:s for s in self.syms};self.syms.sort(key=lambda x:x['addr']);self.addrs=[s['addr'] for s in self.syms]
 def resolve(self,a):
  i=bisect.bisect_right(self.addrs,a)-1
  sec=next((s for s in self.sections if s['addr']<=a<s['addr']+s['size']),None)
  if not sec:return f'unknown:{a:x}'
  if sec['name'] in ['__cstring','__objc_methname','__objc_classname']:
   o=sec['offset']+a-sec['addr'];return sec['name']+':'+self.b[o:self.b.index(b'\0',o)].decode('utf8','replace')
  if i>=0:
   sym=self.syms[i]
   if self.sections[sym['section']-1] is sec:return sym['name']+'+'+str(a-sym['addr'])
  return sec['name']+'+UNRESOLVED:'+str(a-sec['addr'])
 def text_symbols(self):
  sec=next(s for s in self.sections if s['name']=='__text'); ss=[s for s in self.syms if s['section']==self.sections.index(sec)+1];addrs=sorted(set([s['addr'] for s in ss]+[sec['addr']+sec['size']]))
  return {s['name']:{'addr':s['addr'],'size':addrs[bisect.bisect_right(addrs,s['addr'])]-s['addr']} for s in ss}
if __name__=='__main__':
 a,b=[MachO(root/f'products/{k}.app/球迹') for k in ['original','clean']]
 aa,bb=a.text_symbols(),b.text_symbols(); common=aa.keys()&bb.keys()
 rows={'sameSize':sum(aa[n]['size']==bb[n]['size'] for n in common),'changedSize':[{'name':n,'original':aa[n],'clean':bb[n]} for n in sorted(common) if aa[n]['size']!=bb[n]['size']],'originalOnly':[{**v,'name':n} for n,v in aa.items() if n not in bb],'cleanOnly':[{**v,'name':n} for n,v in bb.items() if n not in aa]}
 (root/'text-symbol-size-comparison.json').write_text(json.dumps(rows,indent=2))
 for k,v in rows.items():print(k,v if isinstance(v,int) else len(v))
 for r in rows['changedSize']:print(r['name'],r['original']['size'],r['clean']['size'])

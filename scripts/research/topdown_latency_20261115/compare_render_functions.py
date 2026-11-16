"""Conservative address normalization; unresolved pairs are reported, not hidden."""
import json,re,subprocess,difflib
from compare_macho import MachO,root
bins={k:MachO(root/f'products/{k}.app/球迹') for k in ['original','clean']}
a=bins['original'];b=bins['clean']
candidates=[s['name'] for s in a.syms if s['name'].startswith('_$s5QiuJi')]
demangled=subprocess.check_output(['xcrun','swift-demangle','--compact'],input='\n'.join(candidates)+'\n',text=True).splitlines()
names=[n for n,d in zip(candidates,demangled) if any(x in d for x in ['updateMergedOverlay','makeTemporaryTopDownRenderScene','synchronizeTemporaryTopDownScene','mirrorTemporaryTopDown']) and not n.endswith('Tu')]
report=[]
for idx,name in enumerate(names):
 variants={};raw={}
 for label,m in bins.items():
  s=subprocess.check_output(['xcrun','llvm-objdump','--macho','-d','--dis-symname',name,'--no-show-raw-insn',str(root/f'products/{label}.app/球迹')],text=True)
  (root/f'render-function-{idx}-{label}.asm').write_text(s)
  rows=[]
  for line in s.splitlines():
   mat=re.match(r'([0-9a-f]+):\s*(\S+)\s*(.*)',line)
   if mat: rows.append((int(mat[1],16),mat[2],mat[3]))
  raw[label]=rows
 # Paired instructions; only resolve reference address if register operands agree.
 left,right=raw['original'],raw['clean']; unresolved=[];counts={};pages={}
 if len(left)!=len(right):report.append({'symbol':name,'lengths':[len(left),len(right)]});continue
 for n,(la,lb) in enumerate(zip(left,right)):
  va,op,sa=la;vb,opb,sb=lb
  ca=sa.split(' ;')[0];cb=sb.split(' ;')[0]
  if op!=opb:unresolved.append([n,la,lb]);continue
  def count(k):counts[k]=counts.get(k,0)+1
  if op=='adrp':
   ma=re.match(r'(x\d+), .*; (0x[\da-f]+)',sa);mb=re.match(r'(x\d+), .*; (0x[\da-f]+)',sb)
   if ma and mb and ma[1]==mb[1]:pages[ma[1]]=(int(ma[2],16),int(mb[2],16),n);count('pageReference');continue
  if op in ['add','ldr'] and ' ; ' in sa and ' ; ' in sb:
   commentA=sa.split(' ; ',1)[1];commentB=sb.split(' ; ',1)[1]
   if commentA==commentB and commentA.startswith(('Objc class ref:', 'literal pool symbol address:')) and re.sub(r'#0x[0-9a-f]+','#ADDRESS',ca)==re.sub(r'#0x[0-9a-f]+','#ADDRESS',cb):
    count('resolvedLLVMDataReference');pages.pop(ca.split(',')[0],None);continue
  if op in ['add','ldr','str','ldrb','strb','ldrsw']:
   pa=re.match(r'(\w+), (x\d+), #(0x[\da-f]+)',ca) if op=='add' else re.match(r'(\w+), \[(x\d+)(?:, #(0x[\da-f]+))?\]',ca)
   pb=re.match(r'(\w+), (x\d+), #(0x[\da-f]+)',cb) if op=='add' else re.match(r'(\w+), \[(x\d+)(?:, #(0x[\da-f]+))?\]',cb)
   if pa and pb and pa.groups()[:2]==pb.groups()[:2] and pa[2] in pages:
    aa,bb,origin=pages[pa[2]];aa+=int(pa[3] or '0',16);bb+=int(pb[3] or '0',16)
    ra,rb=a.resolve(aa),b.resolve(bb)
    if ra==rb and 'UNRESOLVED' not in ra and not ra.startswith('unknown'):
     count('resolvedDataReference')
     if op=='add':pages[pa[1]]=(aa,bb,origin)
     elif not op.startswith('str'):pages.pop(pa[1],None)
     continue
    if ca!=cb or aa!=bb:unresolved.append([n,la,lb,ra,rb]);continue
  # LLVM decodes symbol stubs and internal branch symbols; keep their identity.
  if op in ['b','bl'] and 'symbol stub for: ' in sa and 'symbol stub for: ' in sb:
   if sa.split('symbol stub for: ')[1]==sb.split('symbol stub for: ')[1]:count('resolvedCall');continue
  if ca==cb:count('sameOperands')
  else:unresolved.append([n,la,lb])
  # Drop plain register assignment origins; stores/comparisons/branches don't write first operand.
  dst=re.match(r'(x\d+)(?:,|$)',ca)
  if dst and op not in ['str','stp','strb','cmp','tst','cbz','cbnz','tbz','tbnz']:pages.pop(dst[1],None)
 report.append({'symbol':name,'instructionCount':len(left),'counts':counts,'unresolved':unresolved})
(root/'render-function-comparison.json').write_text(json.dumps(report,indent=2))
for r in report:print(r['symbol'],r.get('instructionCount'),len(r.get('unresolved',[])),r.get('lengths'))

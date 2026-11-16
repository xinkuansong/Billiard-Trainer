import argparse, importlib.util, json, shutil, subprocess, xml.etree.ElementTree as ET
from pathlib import Path
HERE=Path(__file__).resolve().parent; REPO=HERE.parents[2]
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--evidence',type=Path,required=True);p.add_argument('--diagnosis',action='store_true');a=p.parse_args()
spec=importlib.util.spec_from_file_location('queue',REPO/'scripts/mac_mini_queue.py');q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
src=a.work/'source';subprocess.run(['git','clone','--shared','--no-checkout',str(REPO),str(src)],check=True,stdout=subprocess.DEVNULL)
before=q.working_files(REPO,q.ROOTS)
for rel in before:
 d=src/rel;d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(REPO/rel,d)
assert before==q.working_files(REPO,q.ROOTS),'Source drift during copy'
assert before==q.working_files(src,q.ROOTS),'Copy mismatch'
(a.evidence/'baseline.json').write_text(json.dumps(before,indent=2))
if a.diagnosis:
 f=src/'QiuJi/Features/DrillLibrary/Views/DrillTutorialView.swift';s=f.read_text();old='.simultaneousGesture(dragGesture)';assert s.count(old)==1;s=s.replace(old,'.simultaneousGesture(dragGesture, including: ProcessInfo.processInfo.arguments.contains("-gallery.disableInnerDrag") ? .none : .all)');f.write_text(s)
 f=src/'QiuJiUITests/V49W12CopyEvidenceUITests.swift';f.write_text(f.read_text()+(HERE/'diagnosis.swift').read_text())
# UI-only validation avoids unrelated unit-test target build; production App is unchanged.
for f in (src/'QiuJi.xcodeproj').rglob('QiuJi.xcscheme'):
 tree=ET.parse(f)
 for parent in list(tree.iter('Testables'))+list(tree.iter('BuildActionEntries')):
  for child in list(parent):
   ref=child.find('BuildableReference')
   if ref is not None and ref.get('BlueprintName')=='QiuJiTests':parent.remove(child)
 tree.write(f,encoding='utf-8',xml_declaration=True)
after=q.working_files(src,q.ROOTS)
changed={k:{'before':before.get(k),'after':v} for k,v in after.items() if before.get(k)!=v}
(a.evidence/'instrumentation.json').write_text(json.dumps(changed,indent=2))
for rel in changed:
 d=a.evidence/'instrumented'/rel;d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src/rel,d)
bundle=a.work/'bundle';m=q.snapshot(src,bundle,dirty=True,quiescent=True)
(a.evidence/'snapshot-manifest.json').write_text(json.dumps(m,indent=2))
print(json.dumps({'bundle':str(bundle),'snapshot':m['snapshot_id']}),flush=True)

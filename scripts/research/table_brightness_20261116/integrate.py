from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys
sys.dont_write_bytecode=True
root=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(root/'scripts'))
from mac_mini_queue import snapshot,tree_files,canonical,write_json,seal,verify
work=Path(os.environ['QIUJI_TEST_WORK']); evidence=Path(os.environ['QIUJI_TEST_EVIDENCE'])
assert os.environ['QIUJI_TEST_RUN_ID']
assert shutil.disk_usage(root).free >= 10*1024**3, 'Need 10GiB full-build reserve'
for name in ['integrate.py','integration.swift']: shutil.copy2(Path(__file__).with_name(name),evidence/name)
bundle=work/'snapshot'
m=snapshot(root,bundle,dirty=True,quiescent=True)
write_json(evidence/'original-manifest.json',m)
f=bundle/'source/QiuJiTests/ClothSupportPerformanceResearchTests.swift'
f.chmod(0o644)
s=f.read_text(); anchor='    // BEGIN H18 R7 INTEGRATION'
assert s.count(anchor)==1
f.write_text(s.replace(anchor,Path(__file__).with_name('integration.swift').read_text()+'\n'+anchor))
# Seal a new candidate identity before any build/launch consumes it.
m['origin']['preview']='approved-C-production-integration-20261116'
m['files']=tree_files(bundle/'source');m.pop('snapshot_id')
m['snapshot_id']=hashlib.sha256(canonical(m)).hexdigest()
bundle.chmod(0o755);(bundle/'manifest.json').chmod(0o644);write_json(bundle/'manifest.json',m);seal(bundle);verify(bundle)
shutil.copy2(f,evidence/'frozen-preview-test.swift')
cmd=[sys.executable,str(root/'scripts/research/cloth_lowdim_20261113/run_native_app.py'),'--snapshot',str(bundle),'--work',str(work),'--evidence',str(evidence),'--expected-count','2','--test','QiuJiTests/ClothSupportPerformanceResearchTests/testTableBrightnessIntegration','--test','QiuJiTests/ClothAppearanceTests/testApprovedBrightnessSurvivesAppearanceAndSceneRebuilds']
sys.exit(subprocess.call(cmd,cwd=root))

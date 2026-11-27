"""Reproduce both native scans within one managed local-test workspace."""
from pathlib import Path
import sys,subprocess,os,json,hashlib
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/defense-maxscore-gallery-20261106'
def run(*args):subprocess.run(list(args),cwd=ROOT,check=True)
run(sys.executable,str(HERE/'prepare.py'))
run(sys.executable,str(HERE/'run.py'))
run(sys.executable,str(HERE/'supplement.py'))
binary=Path(os.environ['QIUJI_TEST_WORK'])/'DefenseBench.app/Worker'
run(sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task',HERE.name,'--',sys.executable,str(HERE/'worker.py'),'{udid}',str(binary),str(OUT/'supplement'))
run(sys.executable,str(HERE/'select_cases.py'))
plotPython=sys.argv[1] if len(sys.argv)>1 else sys.executable
run(plotPython,str(HERE/'render.py'))
(OUT/'workflow-execution.json').write_text(json.dumps({'exitCode':0,'binarySHA256':hashlib.sha256(binary.read_bytes()).hexdigest(),'commands':'prepare, native base, supplement prepare, native supplement, select audit, render'},indent=2))

from pathlib import Path
import time,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-no-recontact-853-20261104/r1';FIRST=ROOT/'output/defense-no-recontact-522-20261104/r1'
def main():
 while True:
  if (FIRST/'failure.json').exists():raise RuntimeError('First batch failed; preserve all evidence before continuing')
  if (FIRST/'execution.json').exists():
   assert json.loads((FIRST/'execution.json').read_text())['exitCode']==0;break
  time.sleep(5)
 cmd=['python3',str(ROOT/'scripts/local_test_lifecycle.py'),'run','--task','defense-no-recontact-853-20261104','--','python3',str(ROOT/'research/defense-no-recontact-853-20261104/run.py')]
 subprocess.run(cmd,cwd=ROOT,check=True)
 subprocess.run(['python3',str(ROOT/'research/defense-no-recontact-853-20261104/merge_all.py')],cwd=ROOT,check=True)

if __name__ == "__main__":main()

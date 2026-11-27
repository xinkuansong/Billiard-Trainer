from pathlib import Path
import sys,subprocess
uid,binary,out=sys.argv[1:];binary=str(Path(binary).resolve());out=Path(out).resolve()
subprocess.run(['xcrun','simctl','boot',uid],check=True)
try:
 subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
 with (out/'run.log').open('w') as log:subprocess.run(['xcrun','simctl','spawn',uid,binary,str(out)],stdout=log,stderr=subprocess.STDOUT,check=True)
finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)

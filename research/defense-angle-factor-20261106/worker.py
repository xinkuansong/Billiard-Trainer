import sys,subprocess
from pathlib import Path
uid,binary,out=sys.argv[1:]
subprocess.run(['xcrun','simctl','boot',uid],check=True)
try:
 subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
 with (Path(out)/'run.log').open('w') as log:
  subprocess.run(['xcrun','simctl','spawn',uid,binary,out],stdout=log,stderr=subprocess.STDOUT,check=True)
finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)

from pathlib import Path
import subprocess,sys
uid,exe,dest=sys.argv[1:]
subprocess.run(['xcrun','simctl','boot',uid],check=True)
try:
 subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
 subprocess.run(['script','-q',dest,'xcrun','simctl','spawn',uid,exe,str(Path(dest).with_suffix('.json'))],check=True)
finally:
 subprocess.run(['xcrun','simctl','shutdown',uid],check=True)

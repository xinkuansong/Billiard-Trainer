from pathlib import Path
import subprocess,sys
device,work,*families=sys.argv[1:]
for family in families:
    subprocess.run([sys.executable,Path(__file__).with_name('check_app.py'),device,work,family],check=True)

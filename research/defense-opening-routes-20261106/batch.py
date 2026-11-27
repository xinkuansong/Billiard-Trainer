import json
from pathlib import Path
import subprocess
import sys
import controller

uid,binary,identity,directory=sys.argv[1:]
controller.OUT=Path(directory)
questions=json.loads((controller.OUT/"inputs.json").read_text())
subprocess.run(["xcrun","simctl","boot",uid],check=True)
try:
    subprocess.run(["xcrun","simctl","bootstatus",uid,"-b"],check=True)
    if len(questions)==39717:
        from rollout_full import run_all
        run_all(controller,questions,uid,binary,identity)
    else:
        controller.phase("pilot",questions,uid,binary,identity)
finally:
    subprocess.run(["xcrun","simctl","shutdown",uid],check=True)

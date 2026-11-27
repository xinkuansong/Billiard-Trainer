from pathlib import Path
import json,subprocess,sys,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/bank-sample-r2-20261101'
OLD=ROOT/'output/local-test-runs/fa65d0e880024f979185302718125354';WORK=OLD/'work';worker=WORK/'KBallWorker.app/Worker'
if len(sys.argv)==1:
    shutil.copy2(HERE/'main.swift',WORK/'source/main.swift')
    cmds=json.loads((OLD/'evidence/commands.json').read_text());compile=next(c for c in cmds if c[-1].endswith('/main.o'))
    with (OUT/'reverify-build.log').open('w') as log:
        for c in [compile,cmds[-1]]:subprocess.run(c,stdout=log,stderr=subprocess.STDOUT,check=True)
    (OUT/'verification-build.json').write_text(json.dumps({'entrySHA256':hashlib.sha256((HERE/'main.swift').read_bytes()).hexdigest(),'workerSHA256':hashlib.sha256(worker.read_bytes()).hexdigest(),'baseBuild':str(OLD),'commands':[compile,cmds[-1]]},indent=2))
    subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','bank-sample-r2-reverify','--',sys.executable,__file__,'worker','{udid}'],check=True)
else:
    uid=sys.argv[2];subprocess.run(['xcrun','simctl','boot',uid],check=True)
    try:
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
        subprocess.run(['xcrun','simctl','spawn',uid,str(worker),'verify',str(OUT)],check=True)
    finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)

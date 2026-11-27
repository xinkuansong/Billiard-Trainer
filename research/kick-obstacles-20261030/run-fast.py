"""Build only the research entry against the already frozen production objects."""
from pathlib import Path
import json,hashlib,os,subprocess,sys,shutil
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/kick-obstacles-20261030';OLD=ROOT/'output/local-test-runs/a4e8d8366a2945deaa3e0b325f4ceb9e'
if len(sys.argv)==1:
    binding=json.loads((OUT/'source-binding.json').read_text())
    for b in binding['sources']:
        if b['currentProduction']:assert hashlib.sha256((ROOT/b['path']).read_bytes()).hexdigest()==b['sha256'],b['path']
    work=Path(os.environ['QIUJI_TEST_WORK']);ev=Path(os.environ['QIUJI_TEST_EVIDENCE']);source=work/'source';shutil.copytree(OLD/'work/source',source)
    shutil.copy2(HERE/'fast-main.swift.txt',source/'main.swift');shutil.copytree(OLD/'work/KBallWorker.app',work/'KBallWorker.app')
    commands=json.loads((OLD/'evidence/commands.json').read_text());cmd=commands[-2]
    cmd=[x.replace(str(OLD/'work/source'),str(source)) if str(OLD/'work/source') in x else x for x in cmd];cmd[-1]=str(work/'main.o')
    link=commands[-1];link=[str(work/'main.o') if x==str(OLD/'work/main.o') else x for x in link];link[-1]=str(work/'KBallWorker.app/Worker')
    (ev/'commands.json').write_text(json.dumps([cmd,link],indent=2))
    with (ev/'build.log').open('w') as log:
        for c in [cmd,link]:subprocess.run(c,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=cmd[cmd.index('-sdk')+1]),check=True)
    (OUT/'fast-binding.json').write_text(json.dumps({'parent':'source-binding.json','entrySHA256':hashlib.sha256((HERE/'fast-main.swift.txt').read_bytes()).hexdigest(),'executableSHA256':hashlib.sha256((work/'KBallWorker.app/Worker').read_bytes()).hexdigest(),'evidence':str(ev)},indent=2))
    subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','compact-pad','--task','kick-obstacles-refined-20261030','--',sys.executable,__file__,'worker','{udid}',str(work/'KBallWorker.app/Worker')],check=True)
else:
    _,uid,worker=sys.argv[1:]
    subprocess.run(['xcrun','simctl','boot',uid],check=True)
    try:
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
        def run(mode,requests):subprocess.run(['xcrun','simctl','spawn',uid,worker,mode,str(requests),str(OUT)],check=True)
        run('check',os.environ.get('KICK_REQUESTS',str(OUT/'placed-refined.json')))
        if os.environ.get('KICK_ADDITIONAL'):
            run('scan',OUT/'requests-additional.json')
            subprocess.run(['/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3',str(HERE/'place.py'),str(OUT/'requests-additional.json'),str(OUT/'placed-additional.json')],check=True)
            run('check',OUT/'placed-additional.json')
    finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)

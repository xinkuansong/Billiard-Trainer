from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
OLD=ROOT/'research/two-ball-sample125-once-20261024'
OUT=ROOT/'output'/HERE.name
src=(OLD/'run.py').read_text()
src=src.replace("HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name", "HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];N=int(sys.argv[2]);OUT=ROOT/'output'/HERE.name/f'p{N}';sys.path.insert(0,str(ROOT/'research/two-ball-sample125-once-20261024'))")
src=src.replace("common.APP=HERE/'Worker.app/Worker'", "common.APP=ROOT/'research/two-ball-sample125-once-20261024/Worker.app/Worker'")
src=src.replace('range(8)','range(N)').replace('})==8','})==N').replace('max_workers=8','max_workers=N').replace('workers=8','workers=N')
src=src.replace(' start=time.monotonic()', ''' from memory import MemoryMonitor
 monitor=MemoryMonitor([w.pid for w in workers],[os.getpid()]+[w.p.pid for w in workers],OUT)
 monitor.start()
 start=time.monotonic()''')
src=src.replace('time.sleep(5)','time.sleep(0.1)')
src=src.replace(' elapsed=time.monotonic()-start', ' elapsed=time.monotonic()-start\n monitor.stop()')
src=src.replace("finally:\n for w", "finally:\n if 'monitor' in globals():monitor.stop()\n for w")
(HERE/'run_round.py').write_text(src)
for n in (8,12,16):
 d=OUT/f'p{n}';d.mkdir(exist_ok=True)
 shutil.copy2(ROOT/'output/two-ball-sample125-once-20261024/layouts.json',d/'layouts.json')
print(HERE/'run_round.py')

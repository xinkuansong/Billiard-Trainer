from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json,subprocess,sys,tempfile
device,folder,action=sys.argv[1:]
root=Path(folder).resolve()
def sim(*args):subprocess.run(['xcrun','simctl',*map(str,args)],check=True)
sim('boot',device)
try:
    sim('bootstatus',device,'-b')
    if action=='effort':sim('spawn',device,root/'Runner.app/Efforts',root)
    elif action=='fill':
        def lane(i):
            sim('spawn',device,root/'Runner.app/Runner','two',i,7,root/'rows')
        with ThreadPoolExecutor(max_workers=7) as pool:list(pool.map(lane,range(7)))
    elif action=='separation':
        with tempfile.TemporaryDirectory(dir=root/'sep') as tmp:
            for i in (0,1,8,30):
                sim('spawn',device,root/'sep/Runner.app/Runner',i,100000,tmp)
                assert json.loads((Path(tmp)/f'sep-{i}.json').read_bytes())==json.loads((root/'sep/rows'/f'sep-{i}.json').read_bytes())

        subprocess.run([sys.executable,Path(__file__).with_name('separation_chunks.py'),device,root/'sep','8'],check=True)
        subprocess.run([sys.executable,Path(__file__).with_name('verify_separation.py'),root/'sep'],check=True)
    else:raise ValueError(action)
finally:sim('shutdown',device)

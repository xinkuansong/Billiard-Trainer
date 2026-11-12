"""Receive verified results from this audit's queued simulator without counting overlapping keys twice."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

def compare_group(local, remote):
    primary=json.loads(local.read_bytes())
    auxiliary=json.loads(remote.read_bytes())
    assert len(primary)==len(auxiliary),local.name
    for a,b in zip(primary,auxiliary):
        if a==b:
            continue
        # Cross-runtime RMS rounding can vary. Require identical inputs, geometry
        # outcome, pocket-jaw count, result and seed. Keep the primary measurement.
        assert a['result']==b['result']=='adjusted',local.name
        assert {k:v for k,v in a.items() if k!='rmsCM'}=={k:v for k,v in b.items() if k!='rmsCM'},local.name
        assert max(a['rmsCM'],b['rmsCM'])<=0.5 and abs(a['rmsCM']-b['rmsCM'])<=0.000002,local.name
        print('Cross-runtime RMS (cm)',a['board'],a['axes'],a['rmsCM'],b['rmsCM'],flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('work', type=Path)
    parser.add_argument('job')
    parser.add_argument('socket')
    options = parser.parse_args()
    work = options.work.resolve()
    host = 'song@fengchuibuchuifengdeMac-mini.local'
    transport = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', '-S', options.socket]
    root = '/Users/song/simulator-work/queue/jobs/' + options.job
    ledger = work / 'sep/rows'
    cache = work / 'mini-row-cache'
    cache.mkdir(exist_ok=True)
    def remote(command):
        return subprocess.run(transport + [host,command], capture_output=True, text=True, check=True).stdout
    def receive():
        state = json.loads(remote('cat ' + root + '/job.json'))['state']
        files = set(remote('ls ' + root + '/evidence').splitlines())
        if 'bank-app-replay.json' in files and not (work/'bank-app-replay.json').exists():
            log = remote('tail -100 ' + root + '/evidence/tests.log')
            if '** TEST EXECUTE SUCCEEDED **' in log or '** TEST SUCCEEDED **' in log:
                data = json.loads(remote('cat ' + root + '/evidence/bank-app-replay.json'))
                total = len(json.loads((work/'bank-changed.json').read_bytes()))
                assert data['expected'] == data['seen'] == total and not data['failed']
                tmp = work/'bank-app-replay.mini.tmp'
                tmp.write_text(json.dumps(data))
                os.replace(tmp,work/'bank-app-replay.json')
                (work/'bank-mini-app.log').write_text(log)
        if 'separation-runtime-parity.json' in files:
            parity = json.loads(remote('cat '+root+'/evidence/separation-runtime-parity.json'))
            assert parity['matched'] and parity['groups']==[0,1,8,30]
            subprocess.run(['rsync','-a','--ignore-existing','-e',' '.join(transport),
                            host+':'+root+'/evidence/sep-rows/',str(cache)+'/'],check=True)
            for file in cache.glob('sep-*.json'):
                index = int(file.stem.split('-')[1])
                dest = ledger/file.name
                if index < parity['start']:
                    assert json.loads(dest.read_bytes()) == json.loads(file.read_bytes())
                    continue
                if dest.exists():
                    if os.path.samefile(dest,file):continue
                    compare_group(dest,file)
                else:
                    rows = json.loads(file.read_bytes())
                    assert 0 < len(rows) <= 64 and len({(r['board'],r['axes']) for r in rows}) == len(rows)
                    try: os.link(file,dest)
                    except FileExistsError: compare_group(dest,file)
        return state
    while True:
        try:
            state=receive()
        except subprocess.CalledProcessError as exc:
            print('Transport pending',exc,flush=True)
            time.sleep(60)
            continue
        if state in ('failed','succeeded','cancelled','interrupted'):
            break
        time.sleep(120)
    print('Remote job '+state,flush=True)
    if state != 'succeeded':sys.exit(1)
    subprocess.run([sys.executable,'scripts/mac_mini_queue.py','fetch','--job',options.job,'--out',work/'mini-final',
                    '--ssh-option','ControlPath='+options.socket,'--complete','--reason','逐项验收结果、运行时对拍及队列回执已回传'],check=True)
if __name__=='__main__':main()

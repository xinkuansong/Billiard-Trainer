"""Resume the frozen pilot after fixed-region filtering, including previously capped routes."""
from pathlib import Path
import sys,os,json,time,subprocess,math,collections,traceback
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
OLD=ROOT/'output/three-ball-placement-pilot-20261026';PILOT=ROOT/'research/three-ball-placement-pilot-20261026'
sys.path.insert(0,str(PILOT));import run as P
P.OUT=OUT
import experiment as E
sys.path.insert(0,str(ROOT/'research/three-ball-comfort-region-20261027'));import region as R
def read(p):return json.loads(p.read_text())
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False))

def next_request(req,last,no):
    q=dict(req)
    if last:
        q['cue']=last['stop'];q['object']=last['finals']['obstacle0']
        q['obstacles']=[last['finals']['obstacle1']] if no==1 else []
    return q

def run_shots(worker,shots,tag,compare=False):
    done=[];last=None
    for i,shot in enumerate(shots):
        q=next_request(shot['request'],last,i);q['id']=tag+'-'+str(i)
        r=worker.run(q,tag.split('-')[0]);assert r['success'],(q['id'],r)
        if compare:
            for field in ['stop','rails','events','finals','cuePath','targetPath']:
                assert r[field]==shot['result'][field],(q['id'],field)
        done.append(dict(request=q,result=r));last=r
    return done

def main(uid):
    filtered=read(OUT/'filter.json');assert not (OUT/'raw.jsonl.gz').exists()
    for path,digest in filtered['inputSHA'].items():assert E.sha(ROOT/path)==digest
    os.environ['THREE_BALL_BUILD_OUTPUT']=str(OUT)
    built=subprocess.run(['make','-C',str(PILOT),'build'],capture_output=True,text=True)
    (OUT/'build-launch.log').write_text(built.stdout+built.stderr)
    assert built.returncode==0,built.stderr+built.stdout
    binary=Path(os.environ['QIUJI_TEST_WORK'])/'ThreeBallWorker.app/Worker'
    worker=None;boot=False;success=False;started=time.monotonic();all_samples=[];protocol=read(OLD/'protocol.json')
    try:
        subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
        worker=P.Worker(uid,binary)
        assert all(worker.ready[k]==E.G[k] for k in ('length','width','radius'))
        for fs in filtered['samples']:
            number=fs['number'];raw=read(OLD/f'sample-{number}.json');sample=raw['sample'];positions=[]
            for candidate in fs['positions']:
                c=dict(candidate);c['chains']=[];c['routeChecks']=[];old=raw['candidates'][c['id']]
                if c['status']!='region_pass':positions.append(c);continue
                valid_first=0
                for rank in c['eligibleRanks']:
                    baseline=raw['baselines'][rank];pocket2=baseline['pocket2'];rc=dict(firstRank=rank,status='pending',attemptedSecond=0,attemptedThird=0);c['routeChecks'].append(rc)
                    oldchain=next((ch for ch in old['chains'] if ch['firstRank']==rank),None)
                    if oldchain:
                        shots=run_shots(worker,oldchain['shots'],f'reuse-s{number}-c{c["id"]}-r{rank}',compare=True)
                        ch={k:v for k,v in oldchain.items() if k!='shots'};ch['shots']=shots;ch['source']='replayed_old_chain'
                        ch['newComfort3']=R.evaluate(shots[2]['request']['cue'],shots[2]['request']['object'],E.ANCHORS[ch['pocket3']]).tolist()
                        c['chains'].append(ch);valid_first+=1;rc['status']='validated_reused'
                    else:
                        q1=dict(baseline['request'],id=f'new-s{number}-c{c["id"]}-r{rank}',obstacles=[sample['second'],c['position']])
                        r1=worker.run(q1,'new_first')
                        if not r1['success']:rc['status']='first_'+r1['reason'];continue
                        if r1['rails']!=baseline['parameter']['rails'] or math.dist(r1['stop'],baseline['result']['stop'])>1e-6:
                            rc['status']='first_state_changed';continue
                        valid_first+=1;matches=[]
                        for trial in raw['secondSearch'].get(str(rank),[]):
                            r2=trial['result']
                            if not E.path_clear(c['position'],r2['cuePath']) or not E.path_clear(c['position'],r2['targetPath']):continue
                            for p3 in range(6):
                                co=E.comfort(r2['stop'],c['position'],p3)
                                if co and co['total']>=85:matches.append((E.effort(r2),-co['total'],p3,trial,co))
                        matches.sort(key=lambda x:(x[0],x[1],x[2],x[3]['request']['id']));rc['secondMatches']=len(matches);cache={}
                        for _,_,p3,trial,co in matches[:24]:
                            key=trial['request']['id']
                            if key not in cache:
                                q2=dict(trial['request'],id=q1['id']+'-second-'+str(len(cache)),cue=r1['stop'],object=r1['finals']['obstacle0'],obstacles=[r1['finals']['obstacle1']],dir=trial['result']['dir'])
                                r2=worker.run(q2,'new_second');cache[key]=(q2,r2);rc['attemptedSecond']+=1
                            q2,r2=cache[key]
                            if not r2['success']:continue
                            third=r2['finals']['obstacle0'];actual=E.comfort(r2['stop'],third,p3)
                            if not actual or actual['total']<85:continue
                            for speed in protocol['thirdFinish']['speeds']:
                                q3=P.request(q1['id']+'-third-'+str(rc['attemptedThird']),r2['stop'],third,p3,dict(v=speed,sx=0,sy=0))
                                r3=worker.run(q3,'new_third');rc['attemptedThird']+=1
                                if r3['success']:
                                    c['chains'].append(dict(firstRank=rank,pocket2=pocket2,pocket3=p3,comfort3=actual,newComfort3=R.evaluate(r2['stop'],third,E.ANCHORS[p3]).tolist(),source='newly_completed_route',shots=[dict(request=q1,result=r1),dict(request=q2,result=r2),dict(request=q3,result=r3)]));rc['status']='validated_new';break
                            if rc['status']=='validated_new':break
                        if rc['status']=='pending':rc['status']='bounded_search_unresolved'
                    if len(c['chains'])>=3:break
                c['status']='validated' if c['chains'] else 'first_routes_rejected' if valid_first==0 else 'continuation_not_found'
                positions.append(c)
            result=dict(sample=sample,positions=positions,counts=dict(collections.Counter(c['status'] for c in positions)))
            write(OUT/f'sample-{number}.json',result);all_samples.append(result)
            print('SAMPLE',number,result['counts'],'chains',sum(len(c['chains']) for c in positions),flush=True)
        # Replay every resulting chain again from the initial board, inheriting
        # actual remaining balls. Exact physical evidence, including dense paths.
        replay_count=0
        for s in all_samples:
            for c in s['positions']:
                for i,ch in enumerate(c['chains']):
                    replay=run_shots(worker,ch['shots'],f'audit-s{s["sample"]["number"]}-c{c["id"]}-{i}',compare=True)
                    for a,b in zip(replay,ch['shots']):assert a['result']['physicalPaths']==b['result']['physicalPaths']
                    replay_count+=1
        binding=read(OUT/'source-binding.json');assert all(E.sha(ROOT/x['path'])==x['sha256'] for x in binding['production'])
        for path,digest in filtered['inputSHA'].items():assert E.sha(ROOT/path)==digest
        total=collections.Counter()
        for s in all_samples:total.update(s['counts'])
        summary=dict(passed=True,counts=dict(total),chains=replay_count,newChains=sum(ch['source']=='newly_completed_route' for s in all_samples for c in s['positions'] for ch in c['chains']),requests=worker.count,kinds=dict(worker.kinds),seconds=time.monotonic()-started,allChainsExactReplay=True,inputsUnchanged=True,thirdComfortGate='original pilot comfort-d2-s3-a2-v1 >=85; new score recorded separately, no extra last-shot rule introduced')
        write(OUT/'flow-audit.json',summary);print('FLOW DONE',summary,flush=True);success=True
    finally:
        code=worker.close() if worker else None
        shutdown=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True) if boot else None
        write(OUT/'closure.json',dict(success=success,nativeExitCode=code,shutdownExitCode=shutdown.returncode if shutdown else None,device=uid,work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE']))
        if code is not None:assert code==0
        if shutdown:assert shutdown.returncode==0,shutdown.stderr

if __name__=='__main__':
    try:main(sys.argv[1])
    except BaseException:write(OUT/'error.json',dict(traceback=traceback.format_exc()));raise

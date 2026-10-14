#!/usr/bin/env python3
"""Run bounded native screenshot jobs from a frozen xctestrun, without rebuilding.
Each worker owns a device, immutable cloned products, isolated output and result bundle.
No automatic retries: failed jobs retain evidence and independent jobs continue.
"""
import argparse, concurrent.futures, hashlib, json, os, plistlib, shutil, subprocess, time
from pathlib import Path
from PIL import Image, ImageStat, ImageOps

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary=path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
    temporary.replace(path)

def run_command(command, log, timeout=600):
    with log.open('ab') as stream:
        stream.write((json.dumps(command,ensure_ascii=False)+'\n').encode());stream.flush()
        process=subprocess.Popen(command,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
        try:return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            import signal
            os.killpg(process.pid,signal.SIGTERM)
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);process.wait()
            return 124

def expand(value, root):
    if isinstance(value,str):return value.replace('__TESTROOT__',str(root))
    if isinstance(value,list):return [expand(v,root) for v in value]
    if isinstance(value,dict):return {k:expand(v,root) for k,v in value.items()}
    return value

def validate(job, output):
    evidence=[];errors=[]
    names=list(job['expected'])
    for prefix in job.get('expectedCovers',[]):
        coverage=output/(prefix+'.coverage.json')
        if not coverage.exists():errors.append('Missing scroll coverage '+prefix);continue
        record=json.loads(coverage.read_text())
        if not record.get('reachedEnd'):errors.append('Scroll end not reached '+prefix)
        expected=[prefix+f'-scroll{i:02d}' for i in range(len(record['names']))]
        if record['names']!=expected or len(expected)<2:errors.append('Invalid scroll sequence '+prefix);continue
        names.extend(expected)
    if len(set(names))!=len(names):raise ValueError('Duplicate screenshot identities')
    for name in names:
        p=output/(name+'.png');m=output/(name+'.json')
        if not p.exists() or not m.exists():errors.append('Missing '+name);continue
        try:
            raw=p
            with Image.open(raw) as im:
                im.load();encodedPixels=im.size;orientation=im.getexif().get(274,1)
                display=ImageOps.exif_transpose(im);pixels=display.size
                if orientation!=1:
                    # Lossless decoding of Apple's orientation tag; original PNG is retained.
                    p=output/(name+'.display.png')
                    if not p.exists():display.save(p)
                    with Image.open(p) as check:
                        if check.size!=display.size or check.convert('RGBA').tobytes()!=display.convert('RGBA').tobytes():
                            raise ValueError('orientation decoding changed pixels')
                thumb=display.convert('RGB');thumb.thumbnail((96,96))
                if max(ImageStat.Stat(thumb).stddev)<2:raise ValueError('near-blank')
            metadata=json.loads(m.read_text());window=metadata['window'];logical=[window['width'],window['height']]
            if logical!=job['size']:raise ValueError('window '+str(logical)+' != '+str(job['size']))
            sx=pixels[0]/logical[0];sy=pixels[1]/logical[1]
            if abs(sx-sy)>0.001 or sx not in (2,3):raise ValueError('invalid pixel scale')
            if metadata['appearance']!=job['theme']:raise ValueError('appearance mismatch')
            evidence.append({'path':str(p),'rawPath':str(raw),'rawSHA256':hashlib.sha256(raw.read_bytes()).hexdigest(),'encodedPixels':encodedPixels,'exifOrientation':orientation,'metadata':str(m),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'pixels':pixels,'window':logical,'scale':sx,'visualReview':'UNREVIEWED','captureStatus':'CAPTURED'})
        except Exception as error:errors.append(name+': '+str(error))
    return evidence,errors

def worker(spec, args):
    udid=spec['udid'];directory=args.output/spec['id'];directory.mkdir(parents=True,exist_ok=False)
    log=directory/'device.log';acquired=False;results=[]
    devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j']))
    found=[d for ds in devices['devices'].values() for d in ds if d['udid']==udid]
    if len(found)!=1 or found[0]['state']!='Shutdown':
        result={'worker':spec['id'],'status':'BLOCKED','reason':'Device missing or already booted; not acquired'};write(directory/'worker.json',result);return result
    write(directory/'initial-device.json',found[0])
    products=directory/'Products';products.mkdir()
    # APFS copy-on-write gives each xcodebuild a different product/container path cheaply.
    subprocess.run(['cp','-cR',str(args.products/'Debug-iphonesimulator'),str(products)],check=True)
    template=plistlib.loads(args.xctestrun.read_bytes())
    try:
        if run_command(['xcrun','simctl','boot',udid],log)!=0:raise RuntimeError('boot failed')
        acquired=True
        if run_command(['xcrun','simctl','bootstatus',udid,'-b'],log)!=0:raise RuntimeError('bootstatus failed')
        for job in spec['jobs']:
            free=shutil.disk_usage(args.output).free
            if (args.output/'STOP').exists() or free < args.min_free_gib*1024**3:
                reason='STOP requested' if (args.output/'STOP').exists() else 'Insufficient disk reserve'
                pending=spec['jobs'][len(results):]
                write(directory/'pending.json',{'reason':reason,'freeBytes':free,'jobs':pending})
                results.append({'status':'BLOCKED','reason':reason,'freeBytes':free,'pendingJobs':[j['id'] for j in pending]})
                break
            output=directory/job['id'];output.mkdir(exist_ok=False);started=time.monotonic();record={**job,'worker':spec['id'],'udid':udid}
            try:
                if run_command(['xcrun','simctl','ui',udid,'appearance',job['theme']],log)!=0:raise RuntimeError('appearance set failed')
                actual=subprocess.check_output(['xcrun','simctl','ui',udid,'appearance'],text=True).strip()
                if actual!=job['theme']:raise RuntimeError('appearance readback failed')
                if run_command(['xcrun','simctl','status_bar',udid,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100'],log)!=0:raise RuntimeError('status bar setup failed')
                test=expand(template,products.resolve());target=test['QiuJiUITests']
                target.setdefault('EnvironmentVariables',{}).update({'V50_SHOT_DIR':str(output.resolve()),'ATLAS_ORIENTATION':job['orientation']})
                if job.get('flow'):
                    flowpath=Path(job['flow']).resolve();flow=json.loads(flowpath.read_text())
                    expected=[s['name'] for s in flow['steps'] if s['action']=='snapshot']
                    if expected!=job['expected'] or len(set(expected))!=len(expected):raise ValueError('flow snapshots differ from expected manifest')
                    covers=[s['name'] for s in flow['steps'] if s['action']=='cover']
                    if covers!=job.get('expectedCovers',[]) or len(set(covers))!=len(covers):raise ValueError('flow covers differ from expected manifest')
                    frozenflow=output/'flow.json';write(frozenflow,flow)
                    target['EnvironmentVariables']['ATLAS_FLOW_PATH']=str(frozenflow)
                target['OnlyTestIdentifiers']=job['selectors']
                testpath=output/'job.xctestrun';testpath.write_bytes(plistlib.dumps(test))
                command=['xcodebuild','test-without-building','-xctestrun',str(testpath),'-destination','platform=iOS Simulator,id='+udid,'-parallel-testing-enabled','NO','-resultBundlePath',str(output/'result.xcresult')]+['-only-testing:QiuJiUITests/'+s for s in job['selectors']]
                code=run_command(command,output/'test.log',timeout=job.get('timeout',240))
                evidence,errors=validate(job,output)
                record.update(exitCode=code,images=evidence,errors=errors,status='CAPTURED_NEEDS_VISUAL_REVIEW' if code==0 and not errors else 'FAILED')
            except Exception as error:record.update(status='FAILED',error=str(error))
            record['elapsedSeconds']=round(time.monotonic()-started,2);results.append(record);write(output/'result.json',record)
            print(spec['id'],job['id'],record['status'],record['elapsedSeconds'],flush=True)
    except Exception as error:results.append({'status':'BLOCKED','error':str(error)})
    finally:
        cleanup={}
        if acquired:
            cleanup['terminate']=run_command(['xcrun','simctl','terminate',udid,'com.xinkuan.qiuji'],log)
            cleanup['shutdown']=run_command(['xcrun','simctl','shutdown',udid],log)
        write(directory/'cleanup.json',{'acquired':acquired,**cleanup})
    result={'worker':spec['id'],'udid':udid,'jobs':results};write(directory/'worker.json',result);return result

def main():
    p=argparse.ArgumentParser();p.add_argument('--config',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--products',type=Path,required=True);p.add_argument('--xctestrun',type=Path,required=True);p.add_argument('--workers',type=int,choices=[1,2],default=1);p.add_argument('--min-free-gib',type=float,default=2);a=p.parse_args()
    if a.min_free_gib < 1:p.error('--min-free-gib must retain at least 1 GiB')
    storage=a.output.absolute()
    while not storage.exists():storage=storage.parent
    free=shutil.disk_usage(storage).free
    if free < a.min_free_gib*1024**3:raise SystemExit(f'BLOCKED: disk free {free/1024**3:.2f} GiB < reserve {a.min_free_gib:g} GiB; no device acquired or output created')
    a.output=a.output.resolve();a.products=a.products.resolve();a.xctestrun=a.xctestrun.resolve();config=json.loads(a.config.read_text());specs=config['workers']
    assert len({s['udid'] for s in specs})==len(specs),'UDID overlap'
    started=time.monotonic();a.output.mkdir(parents=True,exist_ok=False);write(a.output/'config.json',config)
    # Freeze all queued inputs now. Later workers must not consume a newer local build/flow.
    source_products=a.products;frozen=a.output/'frozen-products';frozen.mkdir()
    subprocess.run(['cp','-cR',str(source_products/'Debug-iphonesimulator'),str(frozen)],check=True)
    a.products=frozen
    frozen_test=a.output/'frozen.xctestrun';frozen_test.write_bytes(a.xctestrun.read_bytes());a.xctestrun=frozen_test
    flows=a.output/'frozen-flows';flows.mkdir();flow_hashes={}
    for spec in specs:
        for job in spec['jobs']:
            if not job.get('flow'):continue
            source=Path(job['flow']).resolve();data=source.read_bytes();digest=hashlib.sha256(data).hexdigest()
            target=flows/(digest+'.json')
            if not target.exists():target.write_bytes(data)
            flow_hashes[str(source)]=digest;job['flow']=str(target)
    binaries={}
    product_root=frozen/'Debug-iphonesimulator'
    for bundle in product_root.glob('*.app'):
        info=plistlib.loads((bundle/'Info.plist').read_bytes())
        executable=bundle/info['CFBundleExecutable']
        for file in [executable,*bundle.glob('*.debug.dylib'),*bundle.glob('PlugIns/*.xctest/*')]:
            if file.is_file() and (file==executable or file.suffix=='.dylib' or file.name==file.parent.stem):
                binaries[str(file.relative_to(product_root))]=hashlib.sha256(file.read_bytes()).hexdigest()
    if not binaries:raise RuntimeError('No executable identity found in frozen products')
    write(a.output/'frozen-inputs.json',{'sourceProducts':str(source_products),'binaries':binaries,'flows':flow_hashes,'xctestrunSHA256':hashlib.sha256(frozen_test.read_bytes()).hexdigest()})
    write(a.output/'frozen-config.json',config)
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=a.workers) as pool:
        futures={pool.submit(worker,s,a):s['id'] for s in specs}
        for f in concurrent.futures.as_completed(futures):
            try:results.append(f.result())
            except Exception as error:results.append({'worker':futures[f],'status':'FAILED','error':str(error)})
            write(a.output/'summary.json',{'workers':results,'elapsedSeconds':round(time.monotonic()-started,2),'complete':False})
    failed=any(r.get('status') in ['FAILED','BLOCKED'] or any(j['status'] in ['FAILED','BLOCKED'] for j in r.get('jobs',[])) for r in results)
    write(a.output/'summary.json',{'workers':results,'elapsedSeconds':round(time.monotonic()-started,2),'complete':True,'captureFailures':failed,'visualAcceptance':False})
    raise SystemExit(1 if failed else 0)
if __name__=='__main__':main()

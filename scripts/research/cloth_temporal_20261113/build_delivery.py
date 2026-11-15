from pathlib import Path
import argparse,hashlib,json,plistlib,subprocess
p=argparse.ArgumentParser();p.add_argument('--work',required=True);p.add_argument('--evidence',required=True);p.add_argument('--device');p.add_argument('--non-debug',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[3];work=Path(a.work);evidence=Path(a.evidence)
sources=['QiuJi/Core/Scene/StaticClothIrradiance.swift','QiuJi/Core/Scene/MobileReferenceLighting.swift','QiuJi/Core/Scene/AngleTrainingScene.swift','QiuJi.xcodeproj/project.pbxproj','QiuJi/Resources/StaticClothIrradiance-v1.bin']
sha=lambda path:hashlib.sha256(Path(path).read_bytes()).hexdigest()
before={s:sha(root/s) for s in sources}
if a.device or a.non_debug:
    main=work/'main.swift'
    main.write_bytes((root/'scripts/research/cloth_temporal_20261113/asset_probe_main.swift').read_bytes())
    with (evidence/'preview-contracts.log').open('w') as log:
        for variant,flags in [('debug',['-D','DEBUG']),('nondebug',[])]:
            subprocess.run(['xcrun','swiftc','-O',*flags,str(root/sources[0]),str(main),'-o',str(work/'asset-probe')],
                cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
            for mode in ['valid','missing','corrupt','truncated']:
                subprocess.run([str(work/'asset-probe'),str(root),mode,str(evidence/variant/mode)],
                    cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
    print('Debug/non-DEBUG contracts passed; building iOS app',flush=True)
with (evidence/'ios-build.log').open('w') as log:
    command=['make','-f','scripts/Makefile','build-device-profile','BUILD_DIR='+str(work)]
    if a.non_debug:
        # Exercise production Swift branches without changing the unrelated,
        # currently unready Release API configuration or its HTTPS gate.
        command=['make','-f','scripts/Makefile','test','TEST_ACTION=build',
            'TEST_CONFIGURATION=Debug','TEST_DESTINATION=generic/platform=iOS',
            'BUILD_DIR='+str(work),'DERIVED_DATA='+str(work/'DeviceProfile'),
            'TEST_LOG='+str(evidence/'nondebug-xcodebuild.log'),
            'TEST_JUNIT='+str(evidence/'build.xml'),'TEST_RESULT_BUNDLE=',
            'TEST_BUILD_SETTINGS=SWIFT_ACTIVE_COMPILATION_CONDITIONS= SWIFT_OPTIMIZATION_LEVEL=-O -jobs 4',
            'SIM_TEST_GUARD=']
    subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True)
if a.non_debug:
    import shlex
    commands=[shlex.split(line) for line in (evidence/'nondebug-xcodebuild.log').read_text().splitlines()
              if '/swiftc ' in line and '-module-name QiuJi ' in line]
    if not commands or any('-DDEBUG' in args or any(args[i:i+2]==['-D','DEBUG'] for i in range(len(args))) for args in commands):
        raise ValueError('Production Swift branches were not actually compiled')
app=work/'DeviceProfile/Build/Products/Debug-iphoneos/球迹.app'
asset=app/'StaticClothIrradiance-v1.bin'
assert sha(asset)==before['QiuJi/Resources/StaticClothIrradiance-v1.bin']
verify=subprocess.run(['codesign','--verify','--deep','--strict',str(app)],capture_output=True,text=True)
(evidence/'codesign.log').write_text(verify.stdout+verify.stderr)
assert verify.returncode==0
after={s:sha(root/s) for s in sources};assert before==after,'Build source drift'
(evidence/'build-identity.json').write_text(json.dumps({'buildSucceeded':True,'codesignVerified':True,'bundleAssetExact':True,'assetBytes':asset.stat().st_size,'binarySHA256':sha(app/'球迹'),'sourceSHA256':after,'phoneInstalled':False,'scope':'Debug configuration with non-DEBUG Swift branches; not full Release or phone validation' if a.non_debug else 'Debug iOS build; not runtime/phone rendering validation'},indent=2)+'\n')
print(evidence/'build-identity.json')
if a.device:
    info=plistlib.loads((app/'Info.plist').read_bytes())
    bundle=info['CFBundleIdentifier']
    if bundle!='com.xinkuan.qiuji':
        raise ValueError('Unexpected app identity')
    for label, command in [
        ('install',['xcrun','devicectl','device','install','app','--device',a.device,str(app),'--timeout','180']),
        ('launch',['xcrun','devicectl','device','process','launch','--device',a.device,'--terminate-existing','--timeout','30',bundle]),
    ]:
        command[2:2]=['--json-output',str(evidence/(label+'.json'))]
        (evidence/(label+'-command.json')).write_text(json.dumps(command,indent=2)+'\n')
        print(label+' started',flush=True)
        with (evidence/(label+'.log')).open('w') as log:
            subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=200)
        print(label+' completed',flush=True)
    (evidence/'phone-preview.json').write_text(json.dumps({
        'device':a.device,'bundle':bundle,'version':info['CFBundleShortVersionString'],
        'build':info['CFBundleVersion'],'binarySHA256':sha(app/info['CFBundleExecutable']),
        'installed':True,'launched':True,'launchArguments':[],
        'configuration':'Debug -O; static cloth field enabled by default',
        'scope':'User preview; no claim of phone rendering, performance or thermal acceptance'
    },indent=2)+'\n')

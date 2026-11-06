"""Link the audit driver against exactly the object files in the simulator App build."""
from pathlib import Path
import subprocess,sys,shlex,plistlib
out=Path(sys.argv[1]).resolve()
products=out/'build/Build/Products/Release-iphonesimulator'
app=products/'球迹.app'
runner=out/'Runner.app'
runner.mkdir(exist_ok=True)
for path in app.iterdir():
    if path.name not in ['Info.plist','球迹','PlugIns','_CodeSignature'] and not (runner/path.name).exists():
        (runner/path.name).symlink_to(path)
info=plistlib.loads((app/'Info.plist').read_bytes())
info.update(CFBundleExecutable='Runner',CFBundleIdentifier='local.qiuji.jaw-audit')
(runner/'Info.plist').write_bytes(plistlib.dumps(info))
line=next(line for line in (out/'build.log').read_text().splitlines() if '/clang -Xlinker' in line and line.rstrip().endswith('/球迹.app/球迹'))
cmd=shlex.split(line)
# No writes to the App's linker dependency or LTO metadata.
for flag in ['-dependency_info','-object_path_lto']:
    idx=cmd.index(flag)
    del cmd[idx-1:idx+3]
idx=cmd.index('-dead_strip');del cmd[idx-1:idx+1]
cmd[-1]=str(runner/'libAuditApp.dylib')
cmd+=['-dynamiclib','-install_name','@executable_path/libAuditApp.dylib']
subprocess.run(cmd,check=True)
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
source=Path(__file__).with_name(sys.argv[2] if len(sys.argv)>2 else 'main.swift')
flags=['-parse-as-library'] if source.name!='main.swift' else []
subprocess.run(['xcrun','swiftc',*flags,'-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-O','-I',products,'-L',runner,'-lAuditApp',source,'-o',runner/'Runner'],check=True)

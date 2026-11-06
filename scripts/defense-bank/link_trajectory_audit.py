"""Link the audit command with the actual optimized arm64 Simulator app objects after build-for-testing."""
from pathlib import Path
import shutil
import subprocess
import sys

products=Path(sys.argv[1]).resolve()
out=Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=True)
objects=products.parents[1]/'Intermediates.noindex/QiuJi.build/Debug-iphonesimulator/QiuJi.build/Objects-normal/arm64'
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
flags=['xcrun','swiftc','-O','-swift-version','5','-target','arm64-apple-ios17.0-simulator','-sdk',sdk]
source=out/'app-audit-main.swift'
source.write_text('@testable import QiuJi\n'+Path(__file__).with_name('audit_trajectory.swift').read_text())
subprocess.run([*flags,'-I',products,'-Xfrontend','-entry-point-function-name','-Xfrontend','audit_main','-c',source,'-o',out/'audit.o'],check=True)
app=out/'LinkedAudit.app'
app.mkdir(exist_ok=True)
for name in ['Info.plist','defense-trajectories.bank','PocketPipe','CueStyles','ModelTrial20261010_CueUV.usdz','TaiQiuZhuo.usdz','ModelTrial20261010_TaiQiuZhuo.usdz']:
    src=products/'球迹.app'/name
    if src.is_dir(): shutil.copytree(src, app/name, dirs_exist_ok=True)
    elif src.is_file(): shutil.copy2(src, app/name)
objs=(objects/'球迹.LinkFileList').read_text().splitlines()
subprocess.run([*flags,out/'audit.o',*objs,'-Xlinker','-e','-Xlinker','_audit_main','-lz','-o',app/'Worker'],check=True)

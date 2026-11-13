from pathlib import Path
import hashlib,json,argparse
root=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--out',default='output/render-activity-20261113/c1-app-integration-current')
out=root/parser.parse_args().out
out.mkdir(parents=True,exist_ok=True)
package=root/'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
native=(package/'benchmark.swift').read_text()
prefix=native[:native.index('func calibrate()')]
shim=native[native.index('final class AngleTrainingScene'):]
source=(root/'scripts/research/cloth_temporal_20261113/scene_main.swift').read_text()
helpers=source[source.index('func install('):source.index('func cache(')]
helpers+=source[source.index('func difference('):source.index('try FileManager.default.createDirectory(at:output')]
main=(root/'scripts/research/cloth_temporal_20261113/integration_main.swift').read_text()
main='let fieldAsset=URL(fileURLWithPath:'+json.dumps(str(root/'QiuJi/Resources/StaticClothIrradiance-v1.bin'))+')\n'+main
main=main.replace('device:device)', 'device:device,assetURL:fieldAsset)')
(out/'main.swift').write_text(prefix+main.replace('// __HELPERS__',helpers)+'\n'+shim)
files=['QiuJi/Core/Scene/StaticClothIrradiance.swift','QiuJi/Core/Scene/MobileReferenceLighting.swift','QiuJi/Core/Scene/AngleTrainingScene.swift']
(out/'source-identity.json').write_text(json.dumps({p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in files},indent=2)+'\n')

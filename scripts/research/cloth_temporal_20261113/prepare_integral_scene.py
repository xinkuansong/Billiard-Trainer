from pathlib import Path
root=Path(__file__).resolve().parents[3]
out=root/'output/render-activity-20261113/c1-integral-r2'
native=(root/'output/render-lowdim-20261113/native-scene-guardcombo-package-r2/benchmark.swift').read_text()
prefix=native[:native.index('func calibrate()')]
shim=native[native.index('final class AngleTrainingScene'):]
helper=(root/'scripts/research/cloth_temporal_20261113/scene_main.swift').read_text()
# Reuse scene install, exact image comparison and the unchanged synthetic input.
helpers=helper[helper.index('func install('):helper.index('func cache(')]
helpers+=helper[helper.index('func difference('):helper.index('try FileManager.default.createDirectory(at:output')]
main=(root/'scripts/research/cloth_temporal_20261113/integral_scene_main.swift').read_text()
(out/'scene.swift').write_text(prefix+main.replace('// __HELPERS__',helpers)+'\n'+shim)

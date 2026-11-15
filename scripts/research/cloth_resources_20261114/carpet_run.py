"""Build a source-extracted native consumer for actual baked floor sampling."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--work', required=True, type=Path)
    parser.add_argument('--evidence', required=True, type=Path)
    parser.add_argument('--width', type=int, default=700)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    package = root/'output/render-lowdim-20261113/native-scene-guardcombo-package-r2'
    assert shutil.disk_usage(root).free >= 2*1024**3
    paths = {
        'native': package/'benchmark.swift',
        'helpers': root/'scripts/research/cloth_temporal_20261113/scene_main.swift',
        'room': root/'QiuJi/Core/Scene/BakedTrainingRoom.swift',
        'lighting': root/'QiuJi/Core/Scene/MobileReferenceLighting.swift',
        'field': root/'QiuJi/Core/Scene/StaticClothIrradiance.swift',
        'main': Path(__file__).with_name('carpet.swift'),
    }
    assets = root/'QiuJi/Resources/TrainingRoom'
    files = [Path(__file__), *paths.values(), Path(__file__).with_name('main.swift'),
             root/'QiuJi/Resources/StaticClothIrradiance-v1.bin',
             *[package/p for p in ['candidate.surface', 'assets/table.usdz', 'assets/rail-ao.png', 'reference-environment.hdr', 'rig.json']],
             assets/'TrainingCarpet.jpg']
    for style in ['tournament', 'walnut', 'eastern']:
        files += [assets/f'Carpet_{style}.png']
        for part in ['floor', 'perimeter']:
            files += [assets/f'Room_{style}_{part}.usdz', assets/f'{style}_{part}.png']
    def identity():
        return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    before = identity()
    native, helpers, room, lighting = (paths[k].read_text() for k in ['native', 'helpers', 'room', 'lighting'])
    # Factory, geometry, samplers and image conversion come from current production.
    room_code = room[room.index('enum BakedTrainingRoom {'):room.index('    /// Interior-only closure:')]
    for call in ['        room.addChildNode(makeCeiling(style: style))\n', '        room.addChildNode(makePosters(style: style))\n']:
        assert room_code.count(call) == 1
        room_code = room_code.replace(call, '')
    room_code += room[room.index('    private static func carpetPattern('):room.index('    /// Wall placement follows')]+ '\n}\n'
    room_code = room_code.replace('Bundle.main', 'ResearchAssets').replace('UIImage', 'NSImage')
    room_code = room_code.replace('SCNMatrix4MakeScale(roomLength / yarnTile, roomWidth / yarnTile, 1)',
                                  'SCNMatrix4MakeScale(CGFloat(roomLength / yarnTile), CGFloat(roomWidth / yarnTile), 1)')
    rgba = lighting[lighting.index('    static func roomRGBA('):lighting.index('    // A precomputed-style pool of light')]
    rgba = rgba.replace('UIImage', 'NSImage').replace('image.cgImage,', 'image.cgImage(forProposedRect: nil, context: nil, hints: nil),')
    rgba = rgba.replace('NSImage(cgImage: result)', 'NSImage(cgImage: result, size: NSSize(width: result.width, height: result.height))')
    bridge = '''
enum RoomStyle: String, CaseIterable {case tournament, walnut, eastern}
enum ResearchAssets {
 static func url(forResource name:String,withExtension ext:String)->URL? {
  let value=repository.appendingPathComponent("QiuJi/Resources/TrainingRoom/"+name+"."+ext)
  return FileManager.default.fileExists(atPath:value.path) ? value:nil
 }
 static func path(forResource name:String,ofType ext:String)->String? {url(forResource:name,withExtension:ext)?.path}
}
enum MobileReferenceLighting {
 static func roomTexture(_ name:String)->NSImage {
  roomRGBA(NSImage(contentsOf:ResearchAssets.url(forResource:name,withExtension:"jpg")!)!)
 }
''' + rgba + '\n}\n'
    source = native[:native.index('func calibrate()')]
    source += '\nlet repository=URL(fileURLWithPath:'+json.dumps(str(root))+')\n'
    source += bridge+room_code
    source += helpers[helpers.index('func difference('):helpers.index('try FileManager.default.createDirectory(at:output')]
    # Retain exactly the C1/H9/fragment setup used in the preceding cloth experiment.
    cloth = Path(__file__).with_name('main.swift').read_text()
    source += '\ntry FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)\n'
    source += cloth[cloth.index(' let original=try String'):cloth.index(' func reduce(')]
    source += paths['main'].read_text()+'\n'+native[native.index('final class AngleTrainingScene'):]
    for dest in [args.work, args.evidence]:
        dest.mkdir(parents=True, exist_ok=True)
        (dest/'main.swift').write_text(source)
        shutil.copy2(paths['field'], dest)
    (args.evidence/'source-identity.json').write_text(json.dumps(before, indent=2)+'\n')
    (args.evidence/'scope.json').write_text(json.dumps({
        'extraction': 'Current make/load/carpetPattern and roomRGBA body; UIKit NSImage bridge; bundle URL mapped to immutable source resources',
        'omissions': ['ceiling', 'posters', 'ball and cue geometry', 'App UI'],
        'included': ['actual table with C1/H9', 'actual USDZ floor and perimeter', 'current cloth and room image resources'],
        'width': args.width}, indent=2)+'\n')
    with (args.evidence/'compile.log').open('w') as log:
        subprocess.run(['xcrun', 'swiftc', '-O', '-D', 'DEBUG', str(args.work/'StaticClothIrradiance.swift'),
                        str(args.work/'main.swift'), '-o', str(args.work/'benchmark')], stdout=log, stderr=subprocess.STDOUT, check=True)
    with (args.evidence/'render.log').open('w') as log:
        subprocess.run([str(args.work/'benchmark'), str(package), str(args.evidence), str(args.width), '480'],
                       stdout=log, stderr=subprocess.STDOUT, check=True, timeout=500)
    assert before == identity(), 'Source/asset drift'
    print(args.evidence, flush=True)


if __name__ == '__main__':
    main()

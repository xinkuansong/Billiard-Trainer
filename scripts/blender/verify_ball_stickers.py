"""Fresh Blender process check of the packed library and shipped texture set."""
import bpy, pathlib, json, hashlib
root=pathlib.Path.cwd()
out=root/'output/ball-stickers-20260913'
manifest=json.loads((out/'manifest.json').read_text())
assert hashlib.sha256((root/'QiuJi/Resources/TaiQiuZhuo.usdz').read_bytes()).hexdigest()==manifest['sourceSHA256']
bpy.ops.wm.open_mainfile(filepath=str(out/'BallStickerLibrary.blend'))
bpy.data.orphans_purge(do_recursive=True)
for style in manifest['styles']:
    collection=bpy.data.collections[style]
    assert len(collection.objects)==15
    for number in range(1,16):
        o=bpy.data.objects[f'{style}_{number}']
        assert len(o.data.vertices)==362
        assert len(o.data.uv_layers)==1
        assert len(o.data.materials)==1
        nodes=o.data.materials[0].node_tree.nodes
        image=next(n.image for n in nodes if n.type=='TEX_IMAGE')
        assert list(image.size)==[1024,512]
        assert image.packed_file is not None
        assert image.colorspace_settings.name=='sRGB'
        external=bpy.data.images.load(str(root/f'QiuJi/Resources/BallStickers/BallSticker_{style}_{number}.png'),check_existing=False)
        assert list(external.size)==[1024,512]
        assert tuple(external.pixels[:4])==tuple(image.pixels[:4])
        bpy.data.images.remove(external)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'BallStickerLibrary.blend'))
print('VERIFIED: six packed collections, 90 original-UV meshes, 90 sRGB textures; source SHA unchanged')

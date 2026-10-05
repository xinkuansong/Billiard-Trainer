from pathlib import Path
import shutil,json,hashlib,subprocess
r=Path(__file__).resolve().parents[2];base=r/'output/待发布视频';folder='20261005_V023_母球掉袋-不吃库';out=base/folder
src=r/'output/cue-scratch-selection-20261005/r15-case-label-border';video=src/'V023-six-full-shots-120fps.mp4';cover=r/'output/cue-scratch-selection-20261005/cover-r3-no-cushion/cover.png'
assert (src/'verification.json').exists() and (src/'label-verification.json').exists()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(cover)==sha(out/'封面.png')
history=out/'历史版本';history.mkdir(exist_ok=True)
old=out/'视频.mp4'
if sha(old)!=sha(video):
    saved=history/'视频-r13.mp4'
    if saved.exists():assert sha(saved)==sha(old)
    else:shutil.copy2(old,saved)
    shutil.copy2(out/'校验.json',history/'r13-校验.json')
    tmp=out/'视频-r15.tmp.mp4';shutil.copy2(video,tmp);assert sha(tmp)==sha(video);tmp.replace(old)
assert video.stat().st_size==old.stat().st_size and sha(old)==sha(video)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(old)]));v=next(s for s in probe['streams'] if s['codec_type']=='video');assert (v['width'],v['height'],v['avg_frame_rate'],int(v['nb_frames']))==(1440,2560,'120/1',3430)
p=base/'manifest.json';m=json.loads(p.read_text());e=next(e for e in m['entries'] if e['folder']==folder)
e.update(video=str(video),videoVersion='r15-case-label-border',note='2026-10-05用户确认中文编号白边后生成；当前视频r15＋封面r3，已更新待发布，历史r13另存；未发布')
e['copies']=[{'kind':kind,'source':str(source),'destination':str(dest),'sha256':sha(dest),'bytes':dest.stat().st_size} for kind,source,dest in [('video',video,old),('cover',cover,out/'封面.png')]]
p.write_text(json.dumps(m,ensure_ascii=False,indent=2));(out/'校验.json').write_text(json.dumps({'entry':e,'probe':probe,'sizeAndSHA256Match':True},ensure_ascii=False,indent=2))
p=out/'说明.md';s=p.read_text().replace('当前配对为视频r13与封面r3。','当前配对为视频r15与封面r3；用户确认白边编号方案后已更新视频，历史r13保留在历史版本/视频-r13.mp4。').replace('r13-black-pot-line','r15-case-label-border');s+='\n当前版左上「球形一」至「球形六」白边编号仅在击球前1秒显示，运杆时与轨迹/假想球同时隐藏；声音及运动时间轴与r13一致。\n';p.write_text(s)
for file in ['清单.md','index.html']:
 p=base/file;s=p.read_text().replace('视频r13＋封面r3','视频r15＋封面r3').replace('r13视频＋r3封面','r15视频＋r3封面');p.write_text(s)
p=src/'REPORT.md';s=p.read_text().replace('未发布、未归入待发布。','已更新待发布副本，旧r13保存在该目录的历史版本子目录；大小与SHA-256一致，未发布。');p.write_text(s)
print(json.dumps({'stagedVideo':str(old),'sha256':sha(old),'bytes':old.stat().st_size,'bitRate':v['bit_rate']},ensure_ascii=False))

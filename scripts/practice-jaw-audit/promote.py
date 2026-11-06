"""Replace a verified stage if workspace inputs still match the pinned App bundle."""
import ctypes,hashlib,json,os,shutil,sys,tempfile
from pathlib import Path
from pack import sha
repo=Path(__file__).resolve().parents[2]
work=Path(sys.argv[1]).resolve()
family=sys.argv[2]
name={'bank':'bank-practice-bank.json','kball':'KBallBank','two':'TwoBallBank'}[family]
resources=repo/'QiuJi/Resources'
if family=='two':
    from check_two_pack import verify
    verify(work)
stage=work/'staged'/name
live=resources/name
original=work/'Runner.app'/name
expected=json.loads((work/(family+'-stage.json')).read_text())['digests'][name]
def inventory(tree):
    if tree.is_file():return sha(tree.read_bytes())
    return {p.name:sha(p.read_bytes()) for p in tree.iterdir() if p.is_file()}
if sha((stage/'index.json' if stage.is_dir() else stage).read_bytes())!=expected:raise RuntimeError('candidate changed')
prior=work/(family+'-previous-stage.json')
if prior.exists():
    original=work.parent/'staged'/name
    old_digest=json.loads(prior.read_bytes())['digests'][name]
    if sha((original/'index.json' if original.is_dir() else original).read_bytes())!=old_digest:
        raise RuntimeError('Incorrect prior stage')
if inventory(live)!=inventory(original):raise RuntimeError('workspace no longer matches the scanned bundle')
if stage.is_dir():
    temp=Path(tempfile.mkdtemp(prefix='.jaw-promote-',dir=resources))
    try:
        shutil.copytree(stage,temp,dirs_exist_ok=True)
        library=ctypes.CDLL(None,use_errno=True)
        if library.renamex_np(os.fsencode(temp),os.fsencode(live),2)!=0:raise OSError(ctypes.get_errno(),'atomic directory swap')
    finally:
        shutil.rmtree(temp)
else:
    swift=repo/'QiuJi/Features/BankPractice/BankQuestionPreparer.swift'
    old=sha(live.read_bytes())
    text=swift.read_text()
    binding='static let fingerprint = "'+old+'"'
    if text.count(binding)!=1:raise RuntimeError('bank reader fingerprint changed')
    with tempfile.NamedTemporaryFile(dir=resources,delete=False) as f:
        f.write(stage.read_bytes());temp=Path(f.name)
    temp.chmod(live.stat().st_mode)
    os.replace(temp,live)
    swift.write_text(text.replace(binding,'static let fingerprint = "'+expected+'"'))
overlay=work/('two-adjustment-overlay.json.gz' if family=='two' else family+'-overlay.json.gz')
if overlay.exists():
    patch=repo/'content/practice-jaw-audit'/(family+'.json.gz')
    with tempfile.NamedTemporaryFile(dir=patch.parent,delete=False) as temporary:
        temporary.write(overlay.read_bytes())
    os.chmod(temporary.name,0o644)
    os.replace(temporary.name,patch)
print('Installed',family,expected)

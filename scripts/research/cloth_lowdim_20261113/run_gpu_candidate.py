"""Measure frozen-moment consumer only. Excludes generation, textures and App."""
import argparse,json,subprocess
from pathlib import Path
import numpy as np
import study
ap=argparse.ArgumentParser();ap.add_argument('--native',type=Path,required=True);ap.add_argument('--study',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
ap.add_argument('--repeat-input',type=int,default=64)
ap.add_argument('--eligible-only',action='store_true')
a=ap.parse_args();a.out.mkdir(parents=True,exist_ok=False);rows=[]
for name in ['single','scatter','single_texture_pairs','scatter_texture_pairs']:
 folder=a.study/name
 if not folder.exists():continue
 original_ref=np.fromfile(folder/'reference.bin',dtype='<f4').reshape(-1,16)
 selected=np.load(folder/'candidate-4.npz')['use'] if a.eligible_only else np.ones(len(original_ref),dtype=bool)
 reference=np.tile(original_ref[selected],(a.repeat_input,1))
 samples_path=a.out/f'{name}-samples.bin'
 np.tile(np.fromfile(folder/'samples.bin',dtype='<f4').reshape(-1,12)[selected],(a.repeat_input,1)).tofile(samples_path)
 for k in [4,8,32]:
  output=a.out/f'{name}-K{k}.bin'
  moments_path=a.out/f'{name}-K{k}-moments.bin'
  np.tile(np.fromfile(folder/f'moments-{k}.bin',dtype='<f4').reshape(len(original_ref),-1)[selected],(a.repeat_input,1)).tofile(moments_path)
  cmd=[str(a.native/'evaluate'),str(a.native/'reference.metal'),str(samples_path),str(folder/'balls.bin'),str(output),str(moments_path)]
  p=subprocess.run(cmd,capture_output=True,text=True);output.with_suffix('.log').write_text(p.stdout+p.stderr)
  if p.returncode:raise RuntimeError(p.stdout+p.stderr)
  gpu=np.fromfile(output,dtype='<f4').reshape(-1,16);original=np.load(folder/f'candidate-{k}.npz')
  cpu={key:np.concatenate([original[key][selected]]*a.repeat_input,axis=0) for key in ['S','use','ratio','proxy']};use=cpu['use']
  s=cpu['S'][:,None]*study.COLOR
  err=study.metrics(s,gpu[:,12:15])
  if err['abs_max']>2e-4:raise AssertionError(err)
  # Different kernels can round differently; this is arithmetic verification,
  # not a final-pixel tolerance. Enabled false calls the same reference function.
  if not np.array_equal(gpu[~use],reference[~use]):raise AssertionError('fallback must match original')
  proxy=gpu[:,8:11]*np.array([.02,.16,.004])/study.PI+.35*gpu[:,12:15]
  pe=study.metrics(cpu['proxy'],proxy)
  if pe['abs_max']>2e-4:raise AssertionError(pe)
  rows.append({'scene':name,'K_per_panel':k,'repeat_input':a.repeat_input,'eligible_only':a.eligible_only,'gpu_cpu_specular_agreement':err,'gpu_cpu_changed_terms_proxy_agreement':pe,
    'fallback_bit_identical':True,'timing':json.loads(Path(str(output)+'.json').read_text())})
(a.out/'results.json').write_text(json.dumps({'scope':'Mac numerical kernel frozen-moment CONSUMPTION ONLY. Includes direct fallback. Excludes field generation, sampling/interpolation, final SceneKit and phone.', 'rows':rows},indent=2)+'\n')
print(a.out/'results.json')

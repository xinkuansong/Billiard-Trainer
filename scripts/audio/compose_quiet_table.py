# Percussion muted while preserving RNG draws so room delays stay identical.
"""Quiet Table: original note-level composition and sample-free synthesis."""
from pathlib import Path
import argparse
import json
import wave
import numpy as np

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parents[2] / "build/training-music/source")
OUT = parser.parse_args().output_dir
OUT.mkdir(parents=True, exist_ok=True)
SR = 44100
BPM = 80
BEAT = 60 / BPM
DURATION = 60
N = SR * DURATION
rng = np.random.default_rng(9152026)
mix = np.zeros((N, 2), dtype=np.float64)
room = np.zeros_like(mix)
score = []

def put(signal, beat, gain, pan=0, send=0.18):
    start = round(beat * BEAT * SR)
    indices = (start + np.arange(len(signal))) % N
    stereo = signal[:, None] * gain * np.array([np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)])
    np.add.at(mix, indices, stereo)
    np.add.at(room, indices, stereo * send)

def tone(note, length, kind):
    t = np.arange(round(length * SR)) / SR
    f = 440 * 2 ** ((note - 69) / 12)
    if kind == 'keys':
        # Decaying FM tine, softened fundamental, subtle detuned lower partial.
        mod = 0.55 * np.exp(-t / 0.24) * np.sin(2*np.pi*f*2*t)
        s = np.sin(2*np.pi*f*t + mod) * np.exp(-t/1.65)
        s += 0.10*np.sin(2*np.pi*f*1.0012*t)*np.exp(-t/2.3)
        s += 0.04*np.sin(2*np.pi*f*3*t)*np.exp(-t/0.5)
        s *= 1-np.exp(-t/0.013)
    else:
        s = (np.sin(2*np.pi*f*t) + .22*np.sin(2*np.pi*f*2*t)*np.exp(-t/.35)
             + .06*np.sin(2*np.pi*f*3*t)*np.exp(-t/.15))
        s *= (1-np.exp(-t/.014))*np.exp(-t/.55)
    s *= np.minimum(1, np.maximum(0, (length-t)/.14))
    return s

def note(n, beat, length=3.1, gain=.1, pan=0, kind='keys'):
    score.append(dict(note=n, beat=round(beat,4), seconds=length, instrument=kind))
    put(tone(n,length,kind), beat, gain, pan, .2 if kind=='keys' else .035)

# Ten-bar harmonic sentence, repeated with small variations: tonic, relative
# minor, a suspended subdominant passage, then a spacious dominant resolution.
chords = [
    ('Dmaj9',[54,61,64,69],38), ('Dmaj9',[54,61,64,69],38),
    ('F#m7',[57,61,64,68],42), ('Bm9',[57,61,62,66],35),
    ('Bm9',[54,57,61,66],35), ('Em9',[55,59,62,66],40),
    ('Gmaj9',[54,57,59,62],43), ('Em9',[55,59,62,66],40),
    ('A13',[55,61,66,71],33), ('A13',[55,59,61,66],33),
]
for bar in range(20):
    name, voicing, root = chords[bar%10]
    beat = bar*4
    # Loose hand placement, not quantized blocks; quiet response on select bars.
    for j,n in enumerate(voicing):
        note(n,beat+.04+j*.028,3.5,.065*rng.uniform(.9,1.1),(j-1.5)*.12)
    if bar%5 in (1,3):
        for j,n in enumerate(voicing[1:]):
            note(n,beat+2.65+j*.022,2.6,.031,(j-1)*.16)
    note(root,beat+.025,1.9,.16,0,'bass')
    if bar%5 != 4:
        note(root+7,beat+2.52,1.1,.075,0,'bass')

# A deliberately sparse original motif. The second statement answers rather
# than restating every note; silence is part of the arrangement.
melody = [(1.5,78),(2.6,76),(7.1,73),(10.7,73),(11.5,76),
          (14.6,73),(18.5,69),(23.1,71),(26.5,74),(27.3,73),
          (31.2,71),(34.5,73),(38.6,69),
          (41.5,78),(43.1,76),(47.2,73),(51.1,76),(54.6,73),
          (58.5,69),(63.2,71),(66.5,74),(67.6,78),
          (71.1,76),(74.6,73),(78.5,69)]
for beat,n in melody:
    note(n,beat,2.7,.057*rng.uniform(.88,1.08),.16)

def brush(length, cutoff=3800):
    count=round(length*SR)
    noise=rng.normal(size=count)
    freq=np.fft.rfftfreq(count,1/SR)
    filt=(freq/1000)**2 / (1+(freq/1000)**2) / (1+(freq/cutoff)**6)
    s=np.fft.irfft(np.fft.rfft(noise)*filt,n=count)
    t=np.arange(count)/SR
    s *= (1-np.exp(-t/.014))*np.exp(-t/.085)
    s *= np.minimum(1,(length-t)/.04)
    return s

for bar in range(20):
    for offset in (1.02,3.03):
        put(brush(.36),bar*4+offset,0,-.22,.08)
    for offset in (.55,2.58):
        put(brush(.14,2600),bar*4+offset,0,.25,.04)
    # Soft felt pulse, quieter than the bass; no sharp kick attack.
    t=np.arange(round(.22*SR))/SR
    kick=np.sin(2*np.pi*(49*t+1.2*(1-np.exp(-t/.025))))
    kick*=(1-np.exp(-t/.009))*np.exp(-t/.055)*np.minimum(1,(.22-t)/.03)
    put(kick,bar*4,0,0,0)

# Circular, deterministic room tail: all decays wrap into the beginning of
# the loop, rather than cutting off at the final sample.
for k in range(38):
    delay=.047+k*.041+rng.uniform(-.007,.007)
    wet=np.roll(room,round(delay*SR),axis=0)
    if k%2:
        wet=wet[:,::-1]
    mix += wet*(.16*np.exp(-delay/.43))
mix -= mix.mean(axis=0)
mix *= .60/np.max(np.abs(mix))
pcm=np.round(np.clip(mix,-1,1)*32767).astype('<i2')
path=OUT/'quiet-table-no-percussion-loop.wav'
with wave.open(str(path),'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(pcm.tobytes())
metadata={'title':'静台 · 无打击乐版', 'percussion':False,'bpm':BPM,'duration_seconds':DURATION,
          'bars':20,'key':'D major','method':'Original note-level composition; local mathematical synthesis; no external audio samples or music API.',
          'chord_sentence':[c[0] for c in chords], 'notes':score,
          'verification':{'peak_dbfs':float(20*np.log10(np.max(np.abs(mix)))),
                          'boundary_step':float(np.max(np.abs(mix[0]-mix[-1]))),
                          'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(mix**2))))},
          'limitations':'Instrument timbre is synthesized. Listening acceptance and in-app sound-effect mix have not been verified.'}
(OUT/'composition-no-percussion.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2))
print(json.dumps({'file':str(path),**metadata['verification']}))

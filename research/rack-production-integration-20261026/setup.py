from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
s=(ROOT/'research/rack-power-sweep-20261026/main.swift').read_text();a=s.index('            let originalRack = ');b=s.index('            let cue = ',a);s=s[:a]+'            let rack = RackLayout.make(game, seed: seed)\n'+s[b:]
s=s.replace('"width": width,','"defaultBreakVelocity": BreakFlowRunner.defaultBreakVelocity, "width": width,')
(HERE/'main.swift').write_text(s)

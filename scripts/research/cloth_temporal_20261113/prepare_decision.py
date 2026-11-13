from pathlib import Path
root = Path(__file__).resolve().parents[3]
out = root / 'output/render-activity-20261113/c1-temporal/scene'
native = (out / 'benchmark.swift').read_text()
prefix = native[:native.index('// Appended to the archived')]
shim = native[native.index('final class AngleTrainingScene'):]
main = (root / 'scripts/research/cloth_temporal_20261113/scene_main.swift').read_text()
helpers = main[main.index('func install('):main.index('try FileManager.default.createDirectory(at:output')]
decision = (root / 'scripts/research/cloth_temporal_20261113/decision_main.swift').read_text()
(out / 'decision.swift').write_text(prefix + decision.replace('// __CACHE_HELPERS__', helpers) + '\n' + shim)

# C1 cloth reuse experiments (2026-11-13)

The live outcome is `QiuJi/Core/Scene/StaticClothIrradiance.swift` and its 1 MiB bundled field. Since the user's explicit default-integration request on 2026-11-14, both Debug and Release enable it in the supported shared cloth path. In Debug, `-rendering.noStaticClothField` selects the preceding baseline and `-rendering.referenceCloth` still takes priority; Release ignores diagnostic arguments. See `tasks/render-activity-20261113/C1-DEFAULT-INTEGRATION.md` for integration and `C1-DELIVERY.md` for the earlier opt-in research results.

These historical harnesses use frozen exports already present under `output/render-activity-20261113/b3/`, real pixel fixtures under `output/render-lowdim-20261113/`, and the native USDZ/material package `native-scene-guardcombo-package-r2`. They are not standalone synthetic performance tests. Keep these dependencies or regenerate them from the recorded baseline `354480b97`; do not silently substitute an old/new guard. `prepare.py` deliberately rejects a changed whole-file source identity, even when the six baseline generator sections are unchanged. The final `C1-baseline-identity.json` documents that distinction.

Round map:

- R1: `prepare.py`, `benchmark.swift`, `run.py` (math-only temporal cache).
- R2/R3: `scenekit_binding.swift`, `prepare_scene.py`, `scene_main.swift`, `audit_cache.swift`, `prepare_decision.py`, `decision_main.swift` (actual consumer and rejected cost).
- R4/R5: `prepare_integral.py`, `run_integral.py`, `prepare_integral_scene.py`, `integral_scene_main.swift`, `prepare_samples.py`.
- R6/R7: `prepare_field.py` (add `--compact` for 64×32×16), `field_main.swift`, `field_boundary.py`, `field_validate.swift`.
- R8: `prepare_integration.py --out <new-directory>`, `integration_main.swift`, compiled together with the actual App `StaticClothIrradiance.swift` and `-D DEBUG`. The generated file must be named `main.swift`. Current harness passes the checked-in asset URL; the historical R8 executable generated it on the GPU.
- R9: `bake_field_asset.py` packages the two recorded fields verbatim; `asset_probe_main.swift` checks valid/missing/corrupt/truncated input in separate processes. Compile a copy named `main.swift` with the actual App file and `-O -D DEBUG`; arguments are repository root, mode, new output directory. Final device build uses `build_delivery.py --work ... --evidence ...` under `local_test_lifecycle.py run`.

Native render executables accept `<frozen-native-package> <new-output> <width> <watchdog-seconds> <shader-directory>`. Read back and preserve actual targets. The inputs are synthetic moved ball uniforms over real cloth geometry/material, not billiard playback or a complete App page. Keep A/A noise, CPU preparation, GPU consumption, allocation and approximation errors separate. Do not run concurrent GPU benchmarks, lower failed bounds, or overwrite previous evidence. Phone/thermal testing is intentionally outside this local batch.

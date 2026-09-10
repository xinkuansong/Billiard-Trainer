# 休息倒计时音效：利落电子音

- 用户选择：2026-09-10 由柔和电子音优化候选 ①「更温润」改为 ②「更利落」，以最新选择为准。
- 来源：ElevenLabs `eleven_text_to_sound_v2`；原始生成文件和请求参数保存在 `output/countdown-elevenlabs-20260910/`。
- 后期与选择依据：`output/countdown-soft-refinements-20260910/refine.py`、`manifest.json`、`02-crisper-preview.wav`；保留原音调、缩短尾音、3800Hz低通，非 iPhone 内置铃声。
- 正式资源：`QiuJi/Resources/Audio/RestTimer/countdown.wav`（0.38 秒）与 `complete.wav`（1.05 秒），均为 44.1 kHz / 16-bit / 单声道 PCM WAV。
- 资源校验：正式文件逐字节等于 `02-crisper-tick-1.wav` 与 `02-crisper-complete.wav`，没有重新生成或改变试听音量。
- 行为：休息计时最后 3 秒提示；结束播放对应结束音，保留原结束震动、Live Activity 与页面收起时序。使用自定义 System Sound 句柄并在释放时销毁；文件缺失或加载失败记录错误，不回退到旧铃声。本次换选仅更换两段音频，无播放逻辑修改。
- 打包：沿用 `project.yml` 中现有 Audio folder reference，无需改动工程配置。
- 验证：候选②正式文件与源音频一致；换选后 `make -f scripts/Makefile build` 返回0，`output/countdown-soft-refinements-20260910/build-crisper.log` 含 `BUILD SUCCEEDED`，安装包两段WAV与正式资源逐字节一致。定向diff检查通过。真机静音模式、锁屏、蓝牙与实际球房听感未验证。
- 未提交或发布；保留其他任务已有工作区修改。

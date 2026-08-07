# BilliardTrainer — Build Scripts
# Usage: make <target>
# Run from project root: cd scripts && make help
#        or from root:   make -f scripts/Makefile help

SCHEME       ?= QiuJi
SIM_DEVICE   ?= iPhone 17 Pro
PROJECT_ROOT := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/..
BUILD_DIR    := $(PROJECT_ROOT)/build
DERIVED_DATA := $(BUILD_DIR)/DerivedData
ARCHIVE_PATH := $(BUILD_DIR)/QiuJi.xcarchive
EXPORT_PATH  := $(BUILD_DIR)/export
SCREENSHOTS  := $(BUILD_DIR)/screenshots
WORKSPACE    := $(PROJECT_ROOT)/QiuJi.xcworkspace
XCODEPROJ    := $(PROJECT_ROOT)/QiuJi.xcodeproj

# 优先使用 .xcworkspace（CocoaPods / 微信SDK）；否则用 .xcodeproj
ifeq ($(wildcard $(WORKSPACE)),)
  PROJECT_FLAG := -project $(XCODEPROJ)
else
  PROJECT_FLAG := -workspace $(WORKSPACE)
endif

# 烘焙 / 出片 runner 门（问题集合 v29 W1，真源 QiuJiTests/BakeRunnerGate.swift）：
# 这些 runner 会长跑全量物理并写 git 跟踪的资源，故默认在常规测试里 XCTSkip。
# 标志文件是确定性生效的一路：实测 `TEST_RUNNER_XXX=1` 传不进宿主 App 内的单测进程
# （与本仓 PositionPlaySequenceExportRunnerTests 早年的记录一致），环境变量仅在
# 从 Xcode 用 scheme 环境变量运行时生效，这里一并传只是留作文档。
BAKE_GATE_ENV  := TEST_RUNNER_QIUJI_RUN_BAKE_RUNNERS=1
BAKE_GATE_FLAG := $(BUILD_DIR)/.run-bake-runners

.DEFAULT_GOAL := help

# ────────────────────────────────────────────
# 帮助
# ────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "台球训练伴侣 — 构建脚本"
	@echo "────────────────────────────────────"
	@echo "  make xcodegen     重新生成 Xcode 工程（folder refs 原生生成，无需补丁）"
	@echo "  make build        Debug 构建（仅验证编译，不安装/启动）"
	@echo "  make run          Debug 构建 + 安装 + 在模拟器启动（一条龙）"
	@echo "  make test         运行所有 XCTest"
	@echo "  make position-export  走位序列 JSON → 静帧 + 2D mp4（源 content/position_play/sequences/）"
	@echo "  make position-export-stills  只重渲静帧（修开局图等，保留既有 mp4）"
	@echo "  make thumbnails   动作库缩略图烘焙（Resources/DrillThumbnails/；烘焙 runner 不随 make test 跑）"
	@echo "  make tryout-sync  同步 drill 序列到 App Bundle 试打球形（Resources/DrillBoards/）"
	@echo "  make verify-tutorials  内容不变量全量校验（C1–C4 + I5/I7/I8/I9；C4 也计入退出码）"
	@echo "  make verify-gate  门禁模式校验（pre-push 入口；含 C4 结构对齐，v26 W13 转正）"
	@echo "  make invariant-selftest  不变量检查自测（构造性用例证明每项真会报错）"
	@echo "  make install-hooks  安装 git 钩子（pre-push 内容不变量门禁）"
	@echo "  make tutorial-ledger  生成精讲资产台账（docs/research/精讲资产台账.md）"
	@echo "  make archive      Release Archive（生成 .xcarchive）"
	@echo "  make export       从 Archive 导出 IPA"
	@echo "  make upload       上传 IPA 到 App Store Connect"
	@echo "  make screenshot   当前运行的模拟器截图"
	@echo "  make open         用 Xcode 打开项目"
	@echo "  make clean        清理 build/ 目录"
	@echo "  make dsym         从 Archive 提取 dSYM"
	@echo "────────────────────────────────────"
	@echo "  变量覆盖示例："
	@echo "  make build SIM_DEVICE='iPhone 17 Pro Max'"
	@echo "  make archive SCHEME=BilliardTrainer"
	@echo ""

# ────────────────────────────────────────────
# Xcode 工程重生成
# Resources/{Drills,Plans,Videos,DrillThumbnails} 在 project.yml 的 sources 下用
# `type: folder` + `buildPhase: resources` 声明，xcodegen 原生生成 folder reference，
# 因此可直接 `xcodegen generate`，无需事后补丁（旧 patch-pbxproj-folder-refs.py 已废弃）。
# ────────────────────────────────────────────
.PHONY: xcodegen
xcodegen:
	@echo "→ xcodegen generate ..."
	@cd $(PROJECT_ROOT) && xcodegen generate
	@echo "✅ Xcode 工程已重生成"

# ────────────────────────────────────────────
# Debug 构建
# ────────────────────────────────────────────
.PHONY: build
build:
	@echo "→ Debug 构建..."
	@mkdir -p $(DERIVED_DATA)
	xcodebuild \
	  $(PROJECT_FLAG) \
	  -scheme $(SCHEME) \
	  -configuration Debug \
	  -derivedDataPath $(DERIVED_DATA) \
	  -destination 'platform=iOS Simulator,name=$(SIM_DEVICE),OS=latest' \
	  build \
	  | xcpretty || xcodebuild \
	    $(PROJECT_FLAG) \
	    -scheme $(SCHEME) \
	    -configuration Debug \
	    -derivedDataPath $(DERIVED_DATA) \
	    -destination 'platform=iOS Simulator,name=$(SIM_DEVICE),OS=latest' \
	    build
	@echo "✅ Debug 构建完成"

# ────────────────────────────────────────────
# Debug 构建 + 安装 + 启动到模拟器（一条龙）
# 现象「build succeeded 但模拟器没反应」＝ make build 只编译不安装/启动；用 make run。
# ────────────────────────────────────────────
APP_NAME  ?= 球迹
BUNDLE_ID ?= com.xinkuan.qiuji
APP_PATH  := $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/$(APP_NAME).app

.PHONY: run
run: build
	@echo "→ 启动模拟器 $(SIM_DEVICE)..."
	@open -a Simulator
	@xcrun simctl boot "$(SIM_DEVICE)" 2>/dev/null || true
	@xcrun simctl bootstatus "$(SIM_DEVICE)" -b >/dev/null 2>&1 || true
	@echo "→ 安装 $(APP_PATH)"
	@xcrun simctl install "$(SIM_DEVICE)" "$(APP_PATH)"
	@echo "→ 启动 $(BUNDLE_ID)"
	@xcrun simctl launch "$(SIM_DEVICE)" "$(BUNDLE_ID)"
	@echo "✅ 已在模拟器启动 $(APP_NAME)"

# ────────────────────────────────────────────
# 单元测试
# ────────────────────────────────────────────
.PHONY: test
test:
	@echo "→ 运行 XCTest..."
	@mkdir -p $(DERIVED_DATA)
	xcodebuild \
	  $(PROJECT_FLAG) \
	  -scheme $(SCHEME) \
	  -configuration Debug \
	  -derivedDataPath $(DERIVED_DATA) \
	  -destination 'platform=iOS Simulator,name=$(SIM_DEVICE),OS=latest' \
	  -enableCodeCoverage YES \
	  test \
	  | xcpretty --report junit --output $(BUILD_DIR)/test-results.xml || true
	@echo "✅ 测试完成，报告: $(BUILD_DIR)/test-results.xml"

# ────────────────────────────────────────────
# 走位序列离线复现（#11，ADR-P11-04 / ADR-P11-10）
# 输入：content/position_play/sequences/*.json（真相源，编排台录制直写、进 git）
#       渲染前自动同步进 build/position_play_sequences/ 收件箱（临时试渲可直接丢进收件箱）
# 输出：build/position_play_export/<名称>.mp4 + .gif（物理引擎逐 Step 复现渲染）
# ────────────────────────────────────────────
SEQUENCE_CONTENT_DIR := $(PROJECT_ROOT)/content/position_play/sequences

.PHONY: position-export
position-export:
	@echo "→ 走位序列复现导出..."
	@mkdir -p $(BUILD_DIR)/position_play_sequences $(DERIVED_DATA)
	@if ls $(SEQUENCE_CONTENT_DIR)/*.json >/dev/null 2>&1; then \
	  cp -f $(SEQUENCE_CONTENT_DIR)/*.json $(BUILD_DIR)/position_play_sequences/; \
	  echo "  已同步内容库序列: $$(ls $(SEQUENCE_CONTENT_DIR)/*.json | wc -l | tr -d ' ') 个"; \
	fi
	@touch $(BAKE_GATE_FLAG)
	xcodebuild \
	  $(PROJECT_FLAG) \
	  -scheme $(SCHEME) \
	  -configuration Debug \
	  -derivedDataPath $(DERIVED_DATA) \
	  -destination 'platform=iOS Simulator,name=$(SIM_DEVICE),OS=latest' \
	  -only-testing:QiuJiTests/PositionPlaySequenceExportRunnerTests \
	  $(BAKE_GATE_ENV) \
	  test; \
	  status=$$?; rm -f $(BAKE_GATE_FLAG); test $$status -eq 0
	@echo "✅ 产物目录: $(BUILD_DIR)/position_play_export"

.PHONY: position-export-stills
position-export-stills:
	@echo "→ 走位序列静帧-only 导出（开局图取首杆 before）..."
	@mkdir -p $(BUILD_DIR)/position_play_sequences $(BUILD_DIR)/position_play_export $(DERIVED_DATA)
	@touch $(BUILD_DIR)/position_play_export/.stills-only
	@if ls $(SEQUENCE_CONTENT_DIR)/*.json >/dev/null 2>&1; then \
	  cp -f $(SEQUENCE_CONTENT_DIR)/*.json $(BUILD_DIR)/position_play_sequences/; \
	  echo "  已同步内容库序列: $$(ls $(SEQUENCE_CONTENT_DIR)/*.json | wc -l | tr -d ' ') 个"; \
	fi
	@touch $(BAKE_GATE_FLAG)
	xcodebuild \
	  $(PROJECT_FLAG) \
	  -scheme $(SCHEME) \
	  -configuration Debug \
	  -derivedDataPath $(DERIVED_DATA) \
	  -destination 'platform=iOS Simulator,name=$(SIM_DEVICE),OS=latest' \
	  -only-testing:QiuJiTests/PositionPlaySequenceExportRunnerTests \
	  $(BAKE_GATE_ENV) \
	  test; \
	  status=$$?; rm -f $(BAKE_GATE_FLAG); test $$status -eq 0
	@rm -f $(BUILD_DIR)/position_play_export/.stills-only
	@echo "✅ 静帧已更新: $(BUILD_DIR)/position_play_export"

# ────────────────────────────────────────────
# 动作库缩略图烘焙（问题集合 v29 W1）
# 输入：Resources/Drills/**/*.json 的 animation（Bundle 内）
# 输出：QiuJi/Resources/DrillThumbnails/<drill_id>.png（folder ref，进 App Bundle）
# 本体 = `-only-testing` 限定 runner；环境变量/标志文件只是 runner 内部的门。
# 渲染确定性 ⇒ 内容未变时 PNG 字节可能完全相同、git 无 diff，属正常。
# ────────────────────────────────────────────
THUMBNAIL_DIR := $(PROJECT_ROOT)/QiuJi/Resources/DrillThumbnails

.PHONY: thumbnails
thumbnails:
	@echo "→ 动作库缩略图烘焙 → $(THUMBNAIL_DIR)"
	@mkdir -p $(BUILD_DIR) $(DERIVED_DATA) "$(THUMBNAIL_DIR)"
	@touch $(BAKE_GATE_FLAG)
	xcodebuild \
	  $(PROJECT_FLAG) \
	  -scheme $(SCHEME) \
	  -configuration Debug \
	  -derivedDataPath $(DERIVED_DATA) \
	  -destination 'platform=iOS Simulator,name=$(SIM_DEVICE),OS=latest' \
	  -only-testing:QiuJiTests/DrillThumbnailBakeRunnerTests/test_bakeAllThumbnails \
	  $(BAKE_GATE_ENV) \
	  QIUJI_THUMBNAIL_OUTPUT_DIR="$(THUMBNAIL_DIR)" \
	  TEST_RUNNER_QIUJI_THUMBNAIL_OUTPUT_DIR="$(THUMBNAIL_DIR)" \
	  test; \
	  status=$$?; rm -f $(BAKE_GATE_FLAG); test $$status -eq 0
	@echo "✅ 缩略图已烘焙: $$(ls "$(THUMBNAIL_DIR)"/*.png | wc -l | tr -d ' ') 个 → $(THUMBNAIL_DIR)"

# ────────────────────────────────────────────
# 试打球形同步（方案 20260709-动作库试打模式 D4）
# 输入：content/position_play/sequences/drill_c*.json（真相源，批量出片台产出，
#       与视频示范同源）；seq_* 非 drill 序列不参与。
# 输出：QiuJi/Resources/DrillBoards/（蓝色文件夹引用，进 App Bundle）
# 序列在批量出片台更新后重跑本命令即可刷新试打球形（含删除失效文件）。
# ────────────────────────────────────────────
DRILL_BOARDS_DIR := $(PROJECT_ROOT)/QiuJi/Resources/DrillBoards

.PHONY: tryout-sync
tryout-sync:
	@echo "→ 同步 drill 序列 → $(DRILL_BOARDS_DIR)"
	@mkdir -p "$(DRILL_BOARDS_DIR)"
	@rsync -a --delete \
	  --include='drill_c*.json' --exclude='*' \
	  "$(SEQUENCE_CONTENT_DIR)/" "$(DRILL_BOARDS_DIR)/"
	@echo "✅ 已同步 $$(ls "$(DRILL_BOARDS_DIR)" | wc -l | tr -d ' ') 个球形序列"

# ────────────────────────────────────────────
# 精讲资产同步校验
# 序列 JSON 更新后跑一次，确认出片产物、回填图、精讲引用与结构都跟上了。
# 逐段说明与退出码见 scripts/verify_tutorial_sync.py 文件头。
# ────────────────────────────────────────────
.PHONY: verify-tutorials
verify-tutorials:
	@python3 $(PROJECT_ROOT)/scripts/verify_tutorial_sync.py $(ARGS)

# ────────────────────────────────────────────
# 内容不变量门禁（问题集合 v29 W9；契约 §7）
# verify-gate           = pre-push 钩子的入口。阻塞 C1/C2/C3/C4/I5/I7/I8/I9
#                         （v26 W13：C4 已从 GATE_EXEMPT_CHECKS 移除并转正）。
# invariant-selftest    = 构造性用例：每个检查项都在影子内容库上制造一处不一致，
#                         证明它真会报错（不是永远 PASS 的空壳）。
# install-hooks         = 把 scripts/hooks/* 装进 .git/hooks（git 不跟踪 .git/hooks，
#                         每个克隆都要手动装一次）。
# ────────────────────────────────────────────
.PHONY: verify-gate
verify-gate:
	@python3 $(PROJECT_ROOT)/scripts/verify_tutorial_sync.py --gate $(ARGS)

.PHONY: invariant-selftest
invariant-selftest:
	@python3 $(PROJECT_ROOT)/scripts/selftest_content_invariants.py $(ARGS)

.PHONY: install-hooks
install-hooks:
	@HOOK_DIR=$$(cd $(PROJECT_ROOT) && cd "$$(git rev-parse --git-path hooks)" && pwd); \
	 for hook in $(PROJECT_ROOT)/scripts/hooks/*; do \
	   install -m 755 "$$hook" "$$HOOK_DIR/$$(basename $$hook)"; \
	   echo "✅ 已安装 $$(basename $$hook) → $$HOOK_DIR"; \
	 done

.PHONY: tutorial-ledger
tutorial-ledger:
	@python3 $(PROJECT_ROOT)/scripts/generate_tutorial_ledger.py

# ────────────────────────────────────────────
# Release Archive
# ────────────────────────────────────────────
.PHONY: archive
archive:
	@echo "→ Release Archive..."
	@mkdir -p $(BUILD_DIR)
	xcodebuild \
	  $(PROJECT_FLAG) \
	  -scheme $(SCHEME) \
	  -configuration Release \
	  -derivedDataPath $(DERIVED_DATA) \
	  -archivePath $(ARCHIVE_PATH) \
	  -destination 'generic/platform=iOS' \
	  archive
	@echo "✅ Archive 完成: $(ARCHIVE_PATH)"
	@$(MAKE) dsym

# ────────────────────────────────────────────
# Export IPA（需要 ExportOptions.plist）
# ────────────────────────────────────────────
.PHONY: export
export: archive
	@echo "→ 导出 IPA..."
	@if [ ! -f $(PROJECT_ROOT)/scripts/ExportOptions.plist ]; then \
	  echo "⚠️  scripts/ExportOptions.plist 不存在，请先创建（见注释）"; \
	  exit 1; \
	fi
	xcodebuild \
	  -exportArchive \
	  -archivePath $(ARCHIVE_PATH) \
	  -exportOptionsPlist $(PROJECT_ROOT)/scripts/ExportOptions.plist \
	  -exportPath $(EXPORT_PATH)
	@echo "✅ IPA 导出完成: $(EXPORT_PATH)"

# ExportOptions.plist 示例（手动创建 scripts/ExportOptions.plist）：
# <?xml version="1.0" encoding="UTF-8"?>
# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
# <plist version="1.0"><dict>
#   <key>method</key><string>app-store-connect</string>
#   <key>teamID</key><string>YOUR_TEAM_ID</string>
#   <key>uploadSymbols</key><true/>
#   <key>uploadBitcode</key><false/>
# </dict></plist>

# ────────────────────────────────────────────
# 上传到 App Store Connect
# ────────────────────────────────────────────
.PHONY: upload
upload: export
	@echo "→ 上传到 App Store Connect..."
	@echo "⚠️  [HUMAN] 此步骤需要 App Store Connect API Key（.p8 文件）"
	@echo "   方式一（推荐）：在 Xcode Organizer 手动上传"
	@echo "   方式二（xcrun altool，需配置 API Key）："
	@echo "   xcrun altool --upload-app -f $(EXPORT_PATH)/$(SCHEME).ipa \\"
	@echo "     --apiKey <KEY_ID> --apiIssuer <ISSUER_ID> --type ios"

# ────────────────────────────────────────────
# 模拟器截图
# ────────────────────────────────────────────
.PHONY: screenshot
screenshot:
	@echo "→ 截取当前运行模拟器屏幕..."
	@mkdir -p $(SCREENSHOTS)
	@SCREEN_NUM=$${SCREEN:-$(shell ls $(SCREENSHOTS)/screenshot_*.png 2>/dev/null | wc -l | tr -d ' ')}; \
	 SCREEN_NUM=$$((SCREEN_NUM + 1)); \
	 OUT=$(SCREENSHOTS)/screenshot_$$SCREEN_NUM.png; \
	 xcrun simctl io booted screenshot $$OUT; \
	 echo "✅ 截图保存至: $$OUT"

# ────────────────────────────────────────────
# 提取 dSYM
# ────────────────────────────────────────────
.PHONY: dsym
dsym:
	@DSYM_SRC=$(ARCHIVE_PATH)/dSYMs; \
	 DSYM_DEST=$(BUILD_DIR)/dSYMs; \
	 if [ -d "$$DSYM_SRC" ]; then \
	   mkdir -p $$DSYM_DEST; \
	   cp -R $$DSYM_SRC/* $$DSYM_DEST/; \
	   echo "✅ dSYM 提取至: $$DSYM_DEST"; \
	 else \
	   echo "ℹ️  无 dSYM（模拟器构建或未开启符号）"; \
	 fi

# ────────────────────────────────────────────
# 打开项目
# ────────────────────────────────────────────
.PHONY: open
open:
	@if [ -d $(WORKSPACE) ]; then \
	  open $(WORKSPACE); \
	else \
	  open $(XCODEPROJ); \
	fi

# ────────────────────────────────────────────
# 清理
# ────────────────────────────────────────────
.PHONY: clean
clean:
	@echo "→ 清理 build/ ..."
	rm -rf $(BUILD_DIR)
	@echo "✅ 清理完成"

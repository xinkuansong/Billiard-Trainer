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

.DEFAULT_GOAL := help

# ────────────────────────────────────────────
# 帮助
# ────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "台球训练伴侣 — 构建脚本"
	@echo "────────────────────────────────────"
	@echo "  make build        Debug 构建（验证编译）"
	@echo "  make test         运行所有 XCTest"
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

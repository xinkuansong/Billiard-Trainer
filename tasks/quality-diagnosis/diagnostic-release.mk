# Independent SC37 diagnostic overlay. No archive, install, signing, or upload.
# Invoke this file directly; it includes the frozen project's build variables.
QD_REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
override PROJECT_ROOT := $(QD_REPO_ROOT)/build/quality-diagnosis/snapshot-002
QD_RELEASE_OUTPUT ?= $(QD_REPO_ROOT)/build/quality-diagnosis/formal-b5-release-001
override DERIVED_DATA := $(QD_RELEASE_OUTPUT)/DerivedData
include $(PROJECT_ROOT)/scripts/Makefile

.DEFAULT_GOAL := qd-release
.PHONY: qd-release
qd-release:
	@test -f "$(PROJECT_ROOT)/QiuJi.xcodeproj/project.pbxproj"
	@test -f "$(PROJECT_ROOT)/Config/Release.xcconfig"
	@test "$(SCHEME)" = "QiuJi"
	@case "$(QD_RELEASE_OUTPUT)" in "$(QD_REPO_ROOT)/build/quality-diagnosis/"formal-b5-release-*) ;; *) echo "Refusing output outside diagnostic Release runs" >&2; exit 2;; esac
	@test ! -e "$(QD_RELEASE_OUTPUT)/xcode-build.log" || { echo "Existing run: inspect it; use a new output suffix only for an intentional new run" >&2; exit 2; }
	@mkdir -p "$(DERIVED_DATA)"
	@printf '%s\n' "PROJECT_ROOT=$(PROJECT_ROOT)" "DERIVED_DATA=$(DERIVED_DATA)" "SCHEME=$(SCHEME)" 'CONFIGURATION=Release' 'DESTINATION=generic/platform=iOS Simulator' 'CODE_SIGNING_ALLOWED=NO' > "$(QD_RELEASE_OUTPUT)/invocation.txt"
	@status=0; \
	  xcodebuild $(PROJECT_FLAG) \
	    -scheme "$(SCHEME)" \
	    -configuration Release \
	    -derivedDataPath "$(DERIVED_DATA)" \
	    -destination 'generic/platform=iOS Simulator' \
	    -disableAutomaticPackageResolution \
	    CODE_SIGNING_ALLOWED=NO build \
	    > "$(QD_RELEASE_OUTPUT)/xcode-build.log" 2>&1 || status=$$?; \
	  printf '%s\n' "$$status" > "$(QD_RELEASE_OUTPUT)/xcode-exit.txt"; \
	  printf 'Release diagnostic xcodebuild exit=%s; log=%s\n' "$$status" "$(QD_RELEASE_OUTPUT)/xcode-build.log"; \
	  exit "$$status"

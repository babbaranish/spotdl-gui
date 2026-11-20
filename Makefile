# spotDL for macOS. Run `make` or `make help` to see the targets.
SHELL := /bin/zsh
.DEFAULT_GOAL := help

APP_NAME  := spotDL
VERSION   := $(shell cat VERSION)
BUILD_NUM := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
MIN_MACOS := 14.0
ARCHS     := arm64 x86_64
NATIVE    := $(shell uname -m)

BUILD := build
DIST  := dist
APP   := $(BUILD)/$(APP_NAME).app
DMG   := $(DIST)/$(APP_NAME)-$(VERSION).dmg

CORE_SOURCES := $(wildcard Sources/Core/*.swift)
APP_SOURCES  := $(wildcard Sources/App/*.swift)
TEST_SOURCES := $(wildcard Tests/*.swift)

SWIFTC      := $(shell xcrun -f swiftc)
SDK         := $(shell xcrun --show-sdk-path)
SWIFT_FLAGS := -swift-version 5 -enable-bare-slash-regex -parse-as-library -sdk $(SDK)

# Swift Testing lives in different places in the Command Line Tools and in Xcode.
DEV_DIR         := $(or $(DEVELOPER_DIR),$(shell xcode-select -p))
TESTING_FW_DIR  := $(dir $(firstword $(wildcard \
                     $(DEV_DIR)/Library/Developer/Frameworks/Testing.framework \
                     $(DEV_DIR)/Platforms/MacOSX.platform/Developer/Library/Frameworks/Testing.framework)))
TESTING_LIB_DIR := $(dir $(firstword $(wildcard \
                     $(DEV_DIR)/Library/Developer/usr/lib/lib_TestingInterop.dylib \
                     $(DEV_DIR)/Platforms/MacOSX.platform/Developer/usr/lib/lib_TestingInterop.dylib)))
TESTING_PLUGINS := $(abspath $(dir $(SWIFTC))../lib/swift/host/plugins/testing)
TEST_FLAGS      := -F $(TESTING_FW_DIR) -plugin-path $(TESTING_PLUGINS) \
                   -Xlinker -rpath -Xlinker $(TESTING_FW_DIR) \
                   $(if $(TESTING_LIB_DIR),-Xlinker -rpath -Xlinker $(TESTING_LIB_DIR))

.PHONY: help test app dmg install release format clean

help:
	@echo "make test      Run the unit tests"
	@echo "make app       Build $(APP) (universal: $(ARCHS))"
	@echo "make dmg       Build $(DMG) and its checksum"
	@echo "make install   Build and copy the app to /Applications"
	@echo "make release   Test, build the DMG and publish GitHub release v$(VERSION) (needs gh)"
	@echo "make format    Format sources with SwiftFormat"
	@echo "make clean     Remove $(BUILD)/ and $(DIST)/"

# ---- Tests ---------------------------------------------------------------

test: $(BUILD)/tests
	$(BUILD)/tests

$(BUILD)/tests: $(CORE_SOURCES) $(TEST_SOURCES)
	@test -n "$(TESTING_FW_DIR)" || { echo "Swift Testing not found. Install Xcode or the Command Line Tools: xcode-select --install"; exit 1; }
	@mkdir -p $(@D)
	$(SWIFTC) $(SWIFT_FLAGS) $(TEST_FLAGS) -target $(NATIVE)-apple-macos$(MIN_MACOS) $^ -o $@

# ---- App -----------------------------------------------------------------

app: $(APP)

$(BUILD)/bin/$(APP_NAME)-%: $(CORE_SOURCES) $(APP_SOURCES)
	@mkdir -p $(@D)
	$(SWIFTC) $(SWIFT_FLAGS) -O -target $*-apple-macos$(MIN_MACOS) $^ -o $@

$(BUILD)/icon/AppIcon.icns: scripts/make-icon.swift
	@rm -rf $(BUILD)/icon && mkdir -p $(BUILD)/icon/AppIcon.iconset
	swift scripts/make-icon.swift $(BUILD)/icon/icon.png
	set -e; for s in 16 32 128 256 512; do \
	  sips -z $$s $$s $(BUILD)/icon/icon.png --out $(BUILD)/icon/AppIcon.iconset/icon_$${s}x$${s}.png >/dev/null; \
	  sips -z $$((s*2)) $$((s*2)) $(BUILD)/icon/icon.png --out $(BUILD)/icon/AppIcon.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	iconutil -c icns $(BUILD)/icon/AppIcon.iconset -o $@

$(APP): $(foreach a,$(ARCHS),$(BUILD)/bin/$(APP_NAME)-$(a)) $(BUILD)/icon/AppIcon.icns Resources/Info.plist VERSION
	@rm -rf $@ && mkdir -p $@/Contents/MacOS $@/Contents/Resources
	lipo -create $(foreach a,$(ARCHS),$(BUILD)/bin/$(APP_NAME)-$(a)) -output $@/Contents/MacOS/$(APP_NAME)
	cp $(BUILD)/icon/AppIcon.icns $@/Contents/Resources/AppIcon.icns
	sed -e 's/__VERSION__/$(VERSION)/' -e 's/__BUILD__/$(BUILD_NUM)/' Resources/Info.plist > $@/Contents/Info.plist
	codesign --force --sign - $@
	@echo "Built $@ $(VERSION) ($$(lipo -archs $@/Contents/MacOS/$(APP_NAME)))"

# ---- Distribution --------------------------------------------------------

dmg: $(APP)
	scripts/make-dmg.sh $(APP) $(DMG) "$(APP_NAME) $(VERSION)"

install: $(APP)
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP) /Applications/$(APP_NAME).app
	touch /Applications/$(APP_NAME).app
	@echo "Installed /Applications/$(APP_NAME).app"

release:
	@command -v gh >/dev/null || { echo "Install the GitHub CLI first: brew install gh"; exit 1; }
	@test -z "$$(git status --porcelain)" || { echo "Commit your changes first."; exit 1; }
	@test "$$(git rev-parse HEAD)" = "$$(git rev-parse @{u} 2>/dev/null)" || { echo "Push your commits first."; exit 1; }
	@rc=0; git ls-remote --exit-code --tags origin refs/tags/v$(VERSION) >/dev/null || rc=$$?; \
	  if [ $$rc -eq 0 ]; then echo "v$(VERSION) is already released. Bump VERSION."; exit 1; \
	  elif [ $$rc -ne 2 ]; then echo "Could not reach the origin remote."; exit 1; fi
	@grep -q '^## \[$(VERSION)\]' CHANGELOG.md || { echo "CHANGELOG.md has no ## [$(VERSION)] section."; exit 1; }
	$(MAKE) clean && $(MAKE) test dmg
	awk '/^## \[/ { if (found) exit } /^## \[$(VERSION)\]/ { found = 1; next } found' CHANGELOG.md > $(BUILD)/release-notes.md
	gh release create v$(VERSION) $(DMG) $(DMG).sha256 --target "$$(git rev-parse HEAD)" \
	  --title "$(APP_NAME) $(VERSION)" --notes-file $(BUILD)/release-notes.md

format:
	@command -v swiftformat >/dev/null || { echo "SwiftFormat is not installed. Run: brew install swiftformat"; exit 1; }
	swiftformat Sources Tests scripts

clean:
	rm -rf $(BUILD) $(DIST)

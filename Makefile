APP_NAME = CalendarOverlay
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
SOURCES = $(wildcard Sources/*.swift)
VERSION ?= 0.0.0
SWIFTC_FLAGS = -parse-as-library -framework SwiftUI -framework EventKit -framework AppKit

.PHONY: build build-universal run run-clean clean generate test release

build: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES) Info.plist
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@sed -e 's/$$(EXECUTABLE_NAME)/$(APP_NAME)/g' \
		-e 's/$$(PRODUCT_BUNDLE_IDENTIFIER)/com.calendaroverlay.app/g' \
		-e 's/$$(PRODUCT_NAME)/$(APP_NAME)/g' \
		-e 's/$$(DEVELOPMENT_LANGUAGE)/en/g' \
		Info.plist > $(APP_BUNDLE)/Contents/Info.plist
	swiftc $(SWIFTC_FLAGS) -o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) $(SOURCES)
	@codesign --sign - --force --options runtime --entitlements CalendarOverlay.entitlements $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"

build-universal: $(SOURCES) Info.plist
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@sed -e 's/$$(EXECUTABLE_NAME)/$(APP_NAME)/g' \
		-e 's/$$(PRODUCT_BUNDLE_IDENTIFIER)/com.calendaroverlay.app/g' \
		-e 's/$$(PRODUCT_NAME)/$(APP_NAME)/g' \
		-e 's/$$(DEVELOPMENT_LANGUAGE)/en/g' \
		-e 's/1\.0/$(VERSION)/g' \
		Info.plist > $(APP_BUNDLE)/Contents/Info.plist
	swiftc $(SWIFTC_FLAGS) -target arm64-apple-macosx14.0 -o $(BUILD_DIR)/$(APP_NAME)-arm64 $(SOURCES)
	swiftc $(SWIFTC_FLAGS) -target x86_64-apple-macosx14.0 -o $(BUILD_DIR)/$(APP_NAME)-x86_64 $(SOURCES)
	lipo -create -output $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) \
		$(BUILD_DIR)/$(APP_NAME)-arm64 $(BUILD_DIR)/$(APP_NAME)-x86_64
	@rm $(BUILD_DIR)/$(APP_NAME)-arm64 $(BUILD_DIR)/$(APP_NAME)-x86_64
	@codesign --sign - --force --options runtime --entitlements CalendarOverlay.entitlements $(APP_BUNDLE)
	@echo "Built universal $(APP_BUNDLE) ($(VERSION))"

release: build-universal
	cd $(BUILD_DIR) && zip -r $(APP_NAME)-$(VERSION).zip $(APP_NAME).app
	@echo "Created $(BUILD_DIR)/$(APP_NAME)-$(VERSION).zip"

run: build
	@open $(APP_BUNDLE)

run-clean: build
	@defaults delete com.calendaroverlay.app 2>/dev/null || true
	@open $(APP_BUNDLE)

generate:
	xcodegen generate

test:
	swift test

clean:
	rm -rf $(BUILD_DIR)

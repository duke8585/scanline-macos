APP_NAME = CalendarOverlay
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
SOURCES = $(wildcard Sources/*.swift)

.PHONY: build run run-clean clean generate test

build: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES) Info.plist
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@sed -e 's/$$(EXECUTABLE_NAME)/$(APP_NAME)/g' \
		-e 's/$$(PRODUCT_BUNDLE_IDENTIFIER)/com.calendaroverlay.app/g' \
		-e 's/$$(PRODUCT_NAME)/$(APP_NAME)/g' \
		-e 's/$$(DEVELOPMENT_LANGUAGE)/en/g' \
		Info.plist > $(APP_BUNDLE)/Contents/Info.plist
	swiftc -parse-as-library -o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) \
		$(SOURCES) \
		-framework SwiftUI -framework EventKit -framework AppKit
	@codesign --sign - --force --options runtime --entitlements CalendarOverlay.entitlements $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"

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

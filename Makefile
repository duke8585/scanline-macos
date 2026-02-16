APP_NAME = CalendarOverlay
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
SOURCES = $(wildcard Sources/*.swift)

.PHONY: build run clean

build: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES) Info.plist
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp Info.plist $(APP_BUNDLE)/Contents/
	swiftc -parse-as-library -o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) \
		$(SOURCES) \
		-framework SwiftUI -framework EventKit -framework AppKit
	@echo "Built $(APP_BUNDLE)"

run: build
	@defaults delete com.calendaroverlay.app 2>/dev/null || true
	@open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR)

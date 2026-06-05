.PHONY: bootstrap generate build run test lint format clean help

SCHEME  ?= Boomer
CONFIG  ?= Debug
DEST    ?= platform=macOS

# Building a macOS app needs full Xcode, not just the Command Line Tools. If the
# active developer dir is the CLT, point this build at Xcode.app (no sudo needed).
# Permanent fix: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
ifeq ($(findstring CommandLineTools,$(shell xcode-select -p 2>/dev/null)),CommandLineTools)
ifneq ($(wildcard /Applications/Xcode.app/Contents/Developer),)
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
endif
endif

help:
	@echo "Boomer — make targets:"
	@echo "  bootstrap  install xcodegen/swiftlint/swiftformat, then generate"
	@echo "  generate   regenerate Boomer.xcodeproj from project.yml"
	@echo "  build      build the app"
	@echo "  run        build and launch the app"
	@echo "  test       run the test suite"
	@echo "  lint       swiftlint + swiftformat --lint"
	@echo "  format     swiftformat in place"
	@echo "  clean      remove generated project and build artifacts"

bootstrap:
	@command -v xcodegen   >/dev/null 2>&1 || brew install xcodegen
	@command -v swiftlint  >/dev/null 2>&1 || brew install swiftlint
	@command -v swiftformat >/dev/null 2>&1 || brew install swiftformat
	@$(MAKE) generate

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) -destination '$(DEST)' build

run: build
	@APP_PATH=$$(xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) -showBuildSettings 2>/dev/null \
		| awk '/ BUILT_PRODUCTS_DIR /{d=$$3} / FULL_PRODUCT_NAME /{n=$$3} END{print d"/"n}'); \
	echo "Launching $$APP_PATH"; open "$$APP_PATH"

test:
	xcodebuild test -scheme $(SCHEME) -configuration $(CONFIG) -destination '$(DEST)'

lint:
	swiftlint lint --quiet
	swiftformat --lint .

format:
	swiftformat .

clean:
	rm -rf Boomer.xcodeproj DerivedData build

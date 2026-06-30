.PHONY: guard format test forbidden quality

SWIFT_FORMAT ?= /Library/Developer/CommandLineTools/usr/bin/swift-format

guard: format test forbidden

format:
	$(SWIFT_FORMAT) lint --recursive --strict Package.swift Sources Tests Apps

test:
	swift test

forbidden:
	./scripts/forbidden-patterns.sh

quality:
	./scripts/quality.sh

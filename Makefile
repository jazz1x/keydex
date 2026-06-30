.PHONY: guard format test app-build forbidden quality contract cli-smoke

SWIFT_FORMAT ?= /Library/Developer/CommandLineTools/usr/bin/swift-format

guard: format test app-build forbidden

format:
	$(SWIFT_FORMAT) lint --recursive --strict Package.swift Sources Tests Apps

test:
	swift test

app-build:
	swift build --product KeydexApp

forbidden:
	./scripts/forbidden-patterns.sh

quality:
	./scripts/quality.sh

contract:
	./scripts/project-contract.sh

cli-smoke:
	./scripts/cli-smoke.sh

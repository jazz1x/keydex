.PHONY: guard format test app-build forbidden quality contract cli-smoke app-window-smoke app-accessibility-contract app-accessibility-smoke app-accessibility-evidence-template app-accessibility-evidence-review app-design-contract app-screen-evidence app-screen-evidence-review release-smoke release-signing-readiness

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

app-window-smoke:
	./scripts/app-window-smoke.sh

app-accessibility-contract:
	./scripts/app-accessibility-contract.sh

app-accessibility-smoke:
	./scripts/app-accessibility-smoke.sh

app-accessibility-evidence-template:
	./scripts/app-accessibility-evidence-template.sh

app-accessibility-evidence-review:
	./scripts/app-accessibility-evidence-review.sh

app-design-contract:
	./scripts/app-design-contract.sh

app-screen-evidence:
	./scripts/app-screen-evidence.sh $(SCENARIO)

app-screen-evidence-review:
	./scripts/app-screen-evidence-review.sh

release-smoke:
	./scripts/release-smoke.sh

release-signing-readiness:
	./scripts/release-signing-readiness.sh

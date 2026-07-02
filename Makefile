.PHONY: guard format test app-build forbidden quality contract loop-contract cli-smoke app-window-smoke app-menubar-smoke app-accessibility-contract app-accessibility-smoke app-accessibility-evidence-template app-accessibility-evidence-review app-design-contract app-ux-flow-contract app-evidence-scenarios-contract app-screen-evidence app-screen-evidence-review release-smoke release-signing-readiness release-signing-evidence-template release-signing-evidence-review evidence-status

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

loop-contract:
	./scripts/loop-contract.sh

cli-smoke:
	./scripts/cli-smoke.sh

app-window-smoke:
	./scripts/app-window-smoke.sh

app-menubar-smoke:
	./scripts/app-menubar-smoke.sh

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

app-ux-flow-contract:
	./scripts/app-ux-flow-contract.sh

app-evidence-scenarios-contract:
	./scripts/app-evidence-scenarios-contract.sh

app-screen-evidence:
	./scripts/app-screen-evidence.sh $(SCENARIO)

app-screen-evidence-review:
	./scripts/app-screen-evidence-review.sh

release-smoke:
	./scripts/release-smoke.sh

release-signing-readiness:
	./scripts/release-signing-readiness.sh

release-signing-evidence-template:
	./scripts/release-signing-evidence-template.sh

release-signing-evidence-review:
	./scripts/release-signing-evidence-review.sh

evidence-status:
	./scripts/evidence-status.sh

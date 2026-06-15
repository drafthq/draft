.PHONY: clean help test build build-integrations lint
.DEFAULT_GOAL := help

TEST_SCRIPTS = \
	./tests/test-skill-frontmatter.sh \
	./tests/test-skill-name-security.sh \
	./tests/test-skill-order.sh \
	./tests/test-skill-headers.sh \
	./tests/test-skill-references.sh \
	./tests/test-core-files.sh \
	./tests/test-plugin-manifest.sh \
	./tests/test-build-integrations.sh \
	./tests/test-cli.sh \
	./tests/test-syntax-transforms.sh \
	./tests/test-trigger-functions.sh \
	./tests/test-error-handling.sh \
	./tests/test-tools-registered.sh \
	./tests/test-tools-conventions.sh \
	./tests/test-tools-git-metadata.sh \
	./tests/test-tools-classify-files.sh \
	./tests/test-tools-parse-git-log.sh \
	./tests/test-tools-scan-markers.sh \
	./tests/test-tools-hotspot-rank.sh \
	./tests/test-tools-cycle-detect.sh \
	./tests/test-tools-parse-reports.sh \
	./tests/test-tools-detect-test-framework.sh \
	./tests/test-tools-run-coverage.sh \
	./tests/test-tools-freshness-check.sh \
	./tests/test-tools-adr-index.sh \
	./tests/test-tools-manage-symlinks.sh \
	./tests/test-tools-mermaid-from-graph.sh \
	./tests/test-tools-graph-snapshot.sh \
	./tests/test-tools-graph-init.sh \
	./tests/test-tools-graph-impact.sh \
	./tests/test-tools-graph-callers.sh \
	./tests/test-tools-graph-arch.sh \
	./tests/test-tools-fix-whitespace.sh \
	./tests/test-tools-validate-frontmatter.sh \
	./tests/test-tools-check-scope-conflicts.sh \
	./tests/test-tools-check-skill-line-caps.sh \
	./tests/test-tools-check-track-hygiene.sh \
	./tests/test-tools-diff-templates-vs-tracks.sh \
	./tests/test-tools-migrate-track-frontmatter.sh \
	./tests/test-tools-render-track.sh \
	./tests/test-tools-verify-citations.sh \
	./tests/test-tools-verify-doc-anchors.sh \
	./tests/test-tools-verify-graph-binary.sh

# Phase 0 Foundations hygiene/verification tool tests (per manifest §2.2) — see above

help: ## Show this help message
	@echo "Available targets:"
	@echo "  make test               - Run all tests"
	@echo "  make build              - Build integrations (alias for build-integrations)"
	@echo "  make build-integrations - Build Copilot instructions"
	@echo "  make lint               - Run shellcheck + markdownlint"
	@echo "  make clean              - Clean build artifacts"
	@echo "  make help               - Show this message"

test: ## Run all tests
	@FAILED_SUITES=""; \
	for script in $(TEST_SCRIPTS); do \
		echo ""; \
		if $$script; then \
			: ; \
		else \
			FAILED_SUITES="$$FAILED_SUITES $$script"; \
		fi; \
	done; \
	echo ""; \
	echo "========================================"; \
	if [ -z "$$FAILED_SUITES" ]; then \
		echo "All test suites passed."; \
	else \
		echo "FAILED suites:$$FAILED_SUITES"; \
		exit 1; \
	fi

build: build-integrations ## Build integrations (alias for build-integrations)

build-integrations: ## Build Copilot copilot-instructions.md from skill sources
	@./scripts/build-integrations.sh

lint: ## Run shellcheck and markdownlint
	@./scripts/lint.sh

clean: ## Clean build artifacts
	@rm -f integrations/copilot/.github/copilot-instructions.md
	@rm -f integrations/copilot/.github/copilot-instructions.md.*
	@echo "Cleaned integration build artifacts"

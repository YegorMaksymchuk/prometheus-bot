# Makefile for Telegram Bot - Multi-Platform Builds
# Hides all complexity behind simple commands

# Variables
APP_NAME := kbot
BINARY_NAME := $(APP_NAME)
VERSION ?= latest
REGISTRY ?= quay.io
IMAGE_NAME := $(APP_NAME)
IMAGE_TAG := $(IMAGE_NAME):$(VERSION)
BIN_DIR := bin
GO_VERSION := 1.24.3

# Detect host platform
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Map uname to GOOS/GOARCH
ifeq ($(UNAME_S),Linux)
	HOST_GOOS := linux
endif
ifeq ($(UNAME_S),Darwin)
	HOST_GOOS := darwin
endif
ifeq ($(UNAME_S),Windows_NT)
	HOST_GOOS := windows
endif

ifeq ($(UNAME_M),x86_64)
	HOST_GOARCH := amd64
endif
ifeq ($(UNAME_M),arm64)
	HOST_GOARCH := arm64
endif
ifeq ($(UNAME_M),aarch64)
	HOST_GOARCH := arm64
endif

HOST_PLATFORM := $(HOST_GOOS)-$(HOST_GOARCH)
HOST_IMAGE_TAG := $(IMAGE_NAME):$(HOST_PLATFORM)

# Go build flags
LDFLAGS := -w -s
BUILD_FLAGS := -ldflags="$(LDFLAGS)"

# Docker Buildx builder name
BUILDER_NAME := multiarch-builder

.PHONY: help build test run fmt vet lint clean
.PHONY: linux arm macos windows all
.PHONY: image docker-test docker-test-all docker-run docker-build-all
.PHONY: setup-buildx
.PHONY: release release-package release-create release-upload release-notes

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Local Development Targets (No Docker)
build: ## Build binary for current host platform
	@echo "Building for $(HOST_PLATFORM)..."
	@mkdir -p $(BIN_DIR)
	@GOOS=$(HOST_GOOS) GOARCH=$(HOST_GOARCH) go build $(BUILD_FLAGS) -o $(BIN_DIR)/$(BINARY_NAME)-$(HOST_PLATFORM) ./cmd/kbot/main.go
	@echo "Binary created: $(BIN_DIR)/$(BINARY_NAME)-$(HOST_PLATFORM)"

test: ## Run Go tests locally
	@echo "Running tests..."
	@go test -v -race -coverprofile=coverage.out ./...
	@go tool cover -func=coverage.out || true

run: build ## Run the bot locally (requires TELE_TOKEN)
	@if [ -z "$$TELE_TOKEN" ]; then \
		echo "Error: TELE_TOKEN environment variable is not set"; \
		exit 1; \
	fi
	@echo "Running bot..."
	@./$(BIN_DIR)/$(BINARY_NAME)-$(HOST_PLATFORM)

fmt: ## Format code with go fmt
	@echo "Formatting code..."
	@go fmt ./...

vet: ## Run go vet
	@echo "Running go vet..."
	@go vet ./...

lint: fmt vet ## Run fmt and vet together

# Cross-Platform Build Targets
linux: ## Build binary for Linux (amd64)
	@echo "Building for linux/amd64..."
	@mkdir -p $(BIN_DIR)
	@GOOS=linux GOARCH=amd64 go build $(BUILD_FLAGS) -o $(BIN_DIR)/$(BINARY_NAME)-linux-amd64 ./cmd/kbot/main.go
	@echo "Binary created: $(BIN_DIR)/$(BINARY_NAME)-linux-amd64"

arm: ## Build binary for Linux ARM64
	@echo "Building for linux/arm64..."
	@mkdir -p $(BIN_DIR)
	@GOOS=linux GOARCH=arm64 go build $(BUILD_FLAGS) -o $(BIN_DIR)/$(BINARY_NAME)-linux-arm64 ./cmd/kbot/main.go
	@echo "Binary created: $(BIN_DIR)/$(BINARY_NAME)-linux-arm64"

macos: ## Build binary for macOS (amd64 and arm64)
	@echo "Building for darwin/amd64..."
	@mkdir -p $(BIN_DIR)
	@GOOS=darwin GOARCH=amd64 go build $(BUILD_FLAGS) -o $(BIN_DIR)/$(BINARY_NAME)-darwin-amd64 ./cmd/kbot/main.go
	@echo "Binary created: $(BIN_DIR)/$(BINARY_NAME)-darwin-amd64"
	@echo "Building for darwin/arm64..."
	@GOOS=darwin GOARCH=arm64 go build $(BUILD_FLAGS) -o $(BIN_DIR)/$(BINARY_NAME)-darwin-arm64 ./cmd/kbot/main.go
	@echo "Binary created: $(BIN_DIR)/$(BINARY_NAME)-darwin-arm64"

windows: ## Build binary for Windows (amd64)
	@echo "Building for windows/amd64..."
	@mkdir -p $(BIN_DIR)
	@GOOS=windows GOARCH=amd64 go build $(BUILD_FLAGS) -o $(BIN_DIR)/$(BINARY_NAME)-windows-amd64.exe ./cmd/kbot/main.go
	@echo "Binary created: $(BIN_DIR)/$(BINARY_NAME)-windows-amd64.exe"

all: linux arm macos windows ## Build for all platforms
	@echo "All platform builds completed!"

# Docker Targets
setup-buildx: ## Setup Docker Buildx builder for multi-platform builds
	@if ! docker buildx inspect $(BUILDER_NAME) >/dev/null 2>&1; then \
		echo "Creating buildx builder: $(BUILDER_NAME)..."; \
		docker buildx create --name $(BUILDER_NAME) --use --bootstrap; \
	else \
		echo "Buildx builder $(BUILDER_NAME) already exists"; \
		docker buildx use $(BUILDER_NAME); \
	fi

image: setup-buildx ## Build Docker image for host platform/architecture
	@echo "Building Docker image for $(HOST_PLATFORM)..."
	@docker buildx build \
		--platform $(HOST_GOOS)/$(HOST_GOARCH) \
		--build-arg TARGETOS=$(HOST_GOOS) \
		--build-arg TARGETARCH=$(HOST_GOARCH) \
		--tag $(HOST_IMAGE_TAG) \
		--tag $(IMAGE_TAG) \
		--load \
		--file Dockerfile \
		.
	@echo "Image created: $(HOST_IMAGE_TAG) and $(IMAGE_TAG)"

docker-test: setup-buildx ## Run tests in Docker container for host platform
	@echo "Running tests in Docker for $(HOST_PLATFORM)..."
	@docker buildx build \
		--target test \
		--platform $(HOST_GOOS)/$(HOST_GOARCH) \
		--build-arg TARGETOS=$(HOST_GOOS) \
		--build-arg TARGETARCH=$(HOST_GOARCH) \
		--tag $(IMAGE_NAME):test-$(HOST_PLATFORM) \
		--load \
		--file Dockerfile \
		.
	@echo "Test stage built successfully for $(HOST_PLATFORM)"

docker-test-all: setup-buildx ## Run tests in Docker containers for all platforms
	@echo "Running tests for all platforms..."
	@echo "Testing linux/amd64..."
	@docker buildx build \
		--target test \
		--platform linux/amd64 \
		--build-arg TARGETOS=linux \
		--build-arg TARGETARCH=amd64 \
		--tag $(IMAGE_NAME):test-linux-amd64 \
		--file Dockerfile \
		. || (echo "Tests failed for linux/amd64" && exit 1)
	@echo "✓ Tests passed for linux/amd64"
	@echo ""
	@echo "Testing linux/arm64..."
	@docker buildx build \
		--target test \
		--platform linux/arm64 \
		--build-arg TARGETOS=linux \
		--build-arg TARGETARCH=arm64 \
		--tag $(IMAGE_NAME):test-linux-arm64 \
		--file Dockerfile \
		. || (echo "Tests failed for linux/arm64" && exit 1)
	@echo "✓ Tests passed for linux/arm64"
	@echo ""
	@echo "Testing darwin/amd64..."
	@docker buildx build \
		--target test \
		--platform darwin/amd64 \
		--build-arg TARGETOS=darwin \
		--build-arg TARGETARCH=amd64 \
		--tag $(IMAGE_NAME):test-darwin-amd64 \
		--file Dockerfile \
		. || (echo "Tests failed for darwin/amd64" && exit 1)
	@echo "✓ Tests passed for darwin/amd64"
	@echo ""
	@echo "Testing darwin/arm64..."
	@docker buildx build \
		--target test \
		--platform darwin/arm64 \
		--build-arg TARGETOS=darwin \
		--build-arg TARGETARCH=arm64 \
		--tag $(IMAGE_NAME):test-darwin-arm64 \
		--file Dockerfile \
		. || (echo "Tests failed for darwin/arm64" && exit 1)
	@echo "✓ Tests passed for darwin/arm64"
	@echo ""
	@echo "Testing windows/amd64..."
	@docker buildx build \
		--target test \
		--platform windows/amd64 \
		--build-arg TARGETOS=windows \
		--build-arg TARGETARCH=amd64 \
		--tag $(IMAGE_NAME):test-windows-amd64 \
		--file Dockerfile \
		. || (echo "Tests failed for windows/amd64" && exit 1)
	@echo "✓ Tests passed for windows/amd64"
	@echo ""
	@echo "========================================="
	@echo "All platform tests completed successfully!"
	@echo "========================================="

docker-run: image ## Run the bot in Docker container
	@if [ -z "$$TELE_TOKEN" ]; then \
		echo "Error: TELE_TOKEN environment variable is not set"; \
		exit 1; \
	fi
	@echo "Running container from image $(HOST_IMAGE_TAG)..."
	@docker run --rm -e TELE_TOKEN=$$TELE_TOKEN $(HOST_IMAGE_TAG)

docker-build-all: setup-buildx ## Build Docker images for all platforms
	@echo "Building Docker images for all platforms..."
	@docker buildx build \
		--platform linux/amd64,linux/arm64,darwin/amd64,darwin/arm64,windows/amd64 \
		--tag $(IMAGE_NAME):linux-amd64 \
		--tag $(IMAGE_NAME):linux-arm64 \
		--tag $(IMAGE_NAME):darwin-amd64 \
		--tag $(IMAGE_NAME):darwin-arm64 \
		--tag $(IMAGE_NAME):windows-amd64 \
		--file Dockerfile \
		.
	@echo "Multi-platform build completed (images not loaded, use 'docker buildx imagetools inspect' to verify)"

# Release targets
CHART_DIR := kbot
CHART_NAME := kbot
RELEASE_TAG ?= v1.0.0
RELEASE_TITLE ?= Release $(RELEASE_TAG)
RELEASE_NOTES_FILE := RELEASE_NOTES.md
CHART_VERSION := $(shell grep '^version:' $(CHART_DIR)/Chart.yaml | awk '{print $$2}')

release: check-gh release-notes release-package release-create release-upload ## Create GitHub release with Helm chart
	@echo ""
	@echo "=== Release $(RELEASE_TAG) created successfully! ==="
	@echo "Chart package: $(CHART_NAME)-$(CHART_VERSION).tgz"
	@echo "Release URL: https://github.com/YegorMaksymchuk/prometheus-bot/releases/tag/$(RELEASE_TAG)"
	@echo "Chart URL: https://github.com/YegorMaksymchuk/prometheus-bot/releases/download/$(RELEASE_TAG)/$(CHART_NAME)-$(CHART_VERSION).tgz"

check-gh: ## Check if GitHub CLI is installed
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "Error: GitHub CLI (gh) is not installed"; \
		echo ""; \
		echo "Install it:"; \
		echo "  macOS:   brew install gh"; \
		echo "  Linux:   See https://github.com/cli/cli/blob/trunk/docs/install_linux.md"; \
		echo "  Windows: See https://github.com/cli/cli/blob/trunk/docs/install_windows.md"; \
		echo ""; \
		echo "After installation, authenticate:"; \
		echo "  gh auth login"; \
		echo ""; \
		echo "Alternatively, use GitHub Actions workflow for releases:"; \
		echo "  https://github.com/YegorMaksymchuk/prometheus-bot/actions/workflows/release.yml"; \
		exit 1; \
	fi
	@if ! gh auth status >/dev/null 2>&1; then \
		echo "Warning: GitHub CLI is not authenticated"; \
		echo "Run: gh auth login"; \
		exit 1; \
	fi

release-package: ## Package Helm chart
	@echo "=== Packaging Helm chart ==="
	@if [ ! -d "$(CHART_DIR)" ]; then \
		echo "Error: Chart directory $(CHART_DIR) not found"; \
		exit 1; \
	fi
	@echo "Linting chart..."
	@helm lint $(CHART_DIR) || (echo "Chart linting failed!" && exit 1)
	@echo "Packaging chart..."
	@helm package $(CHART_DIR)
	@echo "Chart packaged: $(CHART_NAME)-$(CHART_VERSION).tgz"

release-notes: ## Generate release notes from template
	@echo "=== Generating release notes ==="
	@if [ ! -f "RELEASE_NOTES_TEMPLATE.md" ]; then \
		echo "Error: RELEASE_NOTES_TEMPLATE.md not found"; \
		exit 1; \
	fi
	@RELEASE_URL="https://github.com/YegorMaksymchuk/prometheus-bot/releases/download/$(RELEASE_TAG)/$(CHART_NAME)-$(CHART_VERSION).tgz" && \
	 INSTALL_INSTRUCTION="helm install $(CHART_NAME) https://github.com/YegorMaksymchuk/prometheus-bot/releases/download/$(RELEASE_TAG)/$(CHART_NAME)-$(CHART_VERSION).tgz --namespace=kbot --create-namespace --set teleToken.secretName=kbot-secret --set teleToken.secretKey=tele-token" && \
	 export CHART_VERSION RELEASE_TAG RELEASE_URL INSTALL_INSTRUCTION && \
	 if command -v envsubst >/dev/null 2>&1; then \
		envsubst < RELEASE_NOTES_TEMPLATE.md > $(RELEASE_NOTES_FILE); \
	 else \
		sed -e "s/\$${CHART_VERSION}/$(CHART_VERSION)/g" \
		    -e "s/\$${RELEASE_TAG}/$(RELEASE_TAG)/g" \
		    -e "s|\$${RELEASE_URL}|$$RELEASE_URL|g" \
		    -e "s|\$${INSTALL_INSTRUCTION}|$$INSTALL_INSTRUCTION|g" \
		    RELEASE_NOTES_TEMPLATE.md > $(RELEASE_NOTES_FILE); \
	 fi
	@echo "Release notes generated: $(RELEASE_NOTES_FILE)"

release-create: check-gh release-package release-notes ## Create GitHub release
	@echo "=== Creating GitHub release $(RELEASE_TAG) ==="
	@if gh release view $(RELEASE_TAG) >/dev/null 2>&1; then \
		echo "Release $(RELEASE_TAG) already exists. Use 'make release-upload' to update it."; \
		exit 1; \
	fi
	@gh release create $(RELEASE_TAG) \
		--title "$(RELEASE_TITLE)" \
		--notes-file $(RELEASE_NOTES_FILE) \
		$(CHART_NAME)-$(CHART_VERSION).tgz
	@echo "Release created successfully"

release-upload: check-gh release-package ## Upload chart to existing release
	@echo "=== Uploading chart to release $(RELEASE_TAG) ==="
	@if ! gh release view $(RELEASE_TAG) >/dev/null 2>&1; then \
		echo "Error: Release $(RELEASE_TAG) does not exist. Create it first with 'make release-create'"; \
		exit 1; \
	fi
	@gh release upload $(RELEASE_TAG) $(CHART_NAME)-$(CHART_VERSION).tgz --clobber
	@echo "Chart uploaded successfully"

# Cleanup
clean: ## Remove test results, artifacts, binaries, and Docker images
	@echo "Cleaning up..."
	@echo "Removing test results and artifacts..."
	@rm -f coverage.out coverage.html
	@echo "Removed test coverage files"
	@echo "Removing binary files..."
	@if [ -d "$(BIN_DIR)" ]; then \
		rm -rf $(BIN_DIR); \
		echo "Removed $(BIN_DIR) directory"; \
	fi
	@echo "Removing Docker images..."
	@docker images --format "{{.Repository}}:{{.Tag}}" | grep "^$(IMAGE_NAME):" | while read img; do \
		echo "Removing image: $$img"; \
		docker rmi $$img 2>/dev/null || true; \
	done
	@echo "Removing Helm chart packages..."
	@rm -f $(CHART_NAME)-*.tgz
	@rm -f $(RELEASE_NOTES_FILE)
	@echo "Cleanup completed"

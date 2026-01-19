# Multi-stage Dockerfile for Go Telegram Bot
# Stage 1: Base - Dependencies and Go environment
FROM golang:1.24.3-alpine AS base

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /app

# Enable Go modules
ENV GO111MODULE=on
ENV CGO_ENABLED=0

# Copy go mod files first for better layer caching
COPY go.mod go.sum ./

# Download dependencies (using BuildKit cache mount for CI/CD optimization)
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Stage 2: Builder - Compile the application
FROM base AS builder

# Build arguments for versioning (can be set in CI/CD)
ARG BUILD_VERSION=unknown
ARG BUILD_TIME
ARG VCS_REF

# Copy source code
COPY . .

# Build the binary with optimizations
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build \
    -ldflags="-w -s -X main.version=${BUILD_VERSION} -X main.buildTime=${BUILD_TIME} -X main.vcsRef=${VCS_REF}" \
    -o /app/kbot \
    ./cmd/kbot/main.go

# Stage 3: Test - Run tests and generate coverage
FROM base AS test

# Copy source code
COPY . .

# Run tests with race detection and coverage
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go test -v -race -coverprofile=coverage.out ./... && \
    go tool cover -html=coverage.out -o coverage.html || true

# Stage 4: Runtime - Minimal production image
FROM gcr.io/distroless/static-debian12:nonroot AS runtime

# Note: CA certificates are already included in distroless static image
# Timezone data not needed - bot only uses time.Now() which doesn't require timezone database

# Copy the compiled binary from builder stage
COPY --from=builder --chown=nonroot:nonroot /app/kbot /app/kbot

# Set working directory
WORKDIR /app

# Use non-root user (distroless provides 'nonroot' user with UID 65532)
USER nonroot:nonroot

# Expose port if needed (Telegram bot doesn't require ports, but good practice)
# EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["/app/kbot"]

# Health check (optional - can be customized based on bot needs)
# HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
#   CMD ["/app/kbot", "--health-check"] || exit 1

# Telegram Bot Project

## Project Overview
This is a Telegram bot project written in Go language. The bot is designed to handle user messages and respond accordingly using the Telegram Bot API.

## Technical Requirements

### Prerequisites
- Go 1.24.3 or higher
- Git
- Docker (for container builds)
- Kubernetes cluster (for deployment)
- Helm 3.x (for Kubernetes deployment)
- Telegram Bot Token (obtained from BotFather)

### Dependencies
- github.com/spf13/cobra - For CLI command handling
- gopkg.in/telebot.v4 - For Telegram bot functionality

## Project Structure
```
.
├── cmd/
│   └── kbot/
│       └── main.go
├── internal/
│   └── bot/
│       └── bot.go
├── kbot/                    # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── .github/
│   └── workflows/
│       └── docker-build-push.yml
├── go.mod
├── go.sum
├── Dockerfile
├── Makefile
└── README.md
```

## Setup Instructions

### Quick Start with Makefile

The project includes a comprehensive Makefile for easy development and deployment.

1. Clone the repository:
```bash
git clone https://github.com/YegorMaksymchuk/prometheus-bot.git
cd prometheus-bot
```

2. Install dependencies:
```bash
go mod download
```

3. Set up environment variables:
```bash
export TELE_TOKEN="your-telegram-bot-token"
# Or create .env file
echo "TELE_TOKEN=your-telegram-bot-token" > .env
```

4. Build and run using Makefile:
```bash
# Build for current platform
make build

# Run the bot
make run

# Or see all available commands
make help
```

### Manual Setup

1. Install dependencies:
```bash
go mod download
```

2. Build the project:
```bash
go build -o kbot cmd/kbot/main.go
```

3. Run the bot:
```bash
./kbot
```

## Build Image and Run in Container

### Using Makefile (Recommended)

```bash
# Build Docker image for current platform
make image

# Run tests in Docker
make docker-test

# Run the bot in Docker container
make docker-run

# Build for all platforms
make docker-build-all
```

### Local Build (Manual)

1. Build container:
```bash
docker build -t kbot:latest .
```

2. Run container:
```bash
docker run -e TELE_TOKEN=${TELE_TOKEN} kbot:latest
```

### Using Pre-built Image from GitHub Container Registry

Images are automatically built and pushed to GitHub Container Registry via GitHub Actions.

```bash
# Pull the image
docker pull ghcr.io/yehormaksymchuk/prometheus-bot:latest

# Run container
docker run -e TELE_TOKEN=${TELE_TOKEN} ghcr.io/yehormaksymchuk/prometheus-bot:latest
```

### CI/CD

Docker images are automatically built and pushed to `ghcr.io/yehormaksymchuk/prometheus-bot` via GitHub Actions:

**Workflow**: `.github/workflows/docker-build-push.yml`

**Triggers:**
- Push to `main` branch (tags as `latest`)
- Git tags starting with `v*` (e.g., `v1.0.0`)
- Pull requests (test and build only, no push)
- Manual dispatch

**Process:**
1. **Test Job**: Runs `make test` and `make lint`
2. **Build Job**: Builds multi-arch Docker image (linux/amd64, linux/arm64)
3. **Push**: Pushes to GitHub Container Registry

**Image**: `ghcr.io/yehormaksymchuk/prometheus-bot:latest`

## Development Rules

### Code Style
1. Follow Go standard formatting:
   - Use `go fmt` for code formatting
   - Follow Go naming conventions
   - Use meaningful variable and function names

2. Documentation:
   - Document all exported functions and types
   - Include comments for complex logic
   - Keep README.md up to date

### Git Workflow
1. Branch naming convention:
   - feature/feature-name
   - bugfix/bug-description
   - hotfix/issue-description

2. Commit messages:
   - Use clear and descriptive messages
   - Follow conventional commits format
   - Reference issue numbers when applicable

3. Pull Requests:
   - Create PRs for all changes
   - Include description of changes
   - Request review from team members

### Testing
1. Write unit tests for all new functionality
2. Maintain test coverage above 80%
3. Run tests before committing:
```bash
# Using Makefile
make test

# Or manually
go test ./...
```

4. Run tests in Docker for all platforms:
```bash
make docker-test-all
```

### Error Handling
1. Use proper error handling throughout the code
2. Log errors appropriately
3. Return meaningful error messages

### Security
1. Never commit sensitive data (tokens, keys)
2. Use environment variables for configuration
3. Validate all user input
4. Implement rate limiting for bot commands

## Bot Features

### Commands
- /start - Initialize the bot
- /help - Display help information
- /status - Check bot status

### Message Handling
- Text messages
- Commands
- Error handling for invalid inputs

## Kubernetes Deployment

### Using Helm Chart

The project includes a Helm chart for easy Kubernetes deployment.

1. Create namespace and secret:
```bash
kubectl create namespace kbot
kubectl create secret generic kbot-secret \
    --from-literal=tele-token=<YOUR_TELEGRAM_TOKEN> \
    --namespace=kbot
```

2. Install using Helm:
```bash
# From GitHub release
helm install kbot https://github.com/YegorMaksymchuk/prometheus-bot/releases/download/v1.0.0/kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace

# Or from local chart
helm install kbot ./kbot-0.1.0.tgz \
    --namespace=kbot \
    --create-namespace \
    --set teleToken.secretName=kbot-secret \
    --set teleToken.secretKey=tele-token
```

3. Check deployment:
```bash
kubectl get all -n kbot
kubectl logs -l app.kubernetes.io/name=kbot -n kbot
```

See `HELM_CHART_SUMMARY.md` and `MANUAL_TEST.md` for detailed instructions.

## Contributing
1. Fork the repository
2. Create a feature branch (e.g., `feature/my-feature`)
3. Make your changes and run tests: `make test`
4. Commit your changes (follow conventional commits)
5. Push to the branch
6. Create a Pull Request

**Note**: All PRs automatically run tests via GitHub Actions before merge.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Contact
For any questions or issues, please create an issue in the repository. 
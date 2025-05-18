# Telegram Bot Project

## Project Overview
This is a Telegram bot project written in Go language. The bot is designed to handle user messages and respond accordingly using the Telegram Bot API.

## Technical Requirements

### Prerequisites
- Go 1.21 or higher
- Git
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
├── go.mod
├── go.sum
└── README.md
```

## Setup Instructions

1. Clone the repository:
```bash
git clone <repository-url>
cd bot-telegram
```

2. Install dependencies:
```bash
go mod download
```

3. Set up environment variables:
```bash
export TELE_TOKEN="your-telegram-bot-token"
```

4. Build the project:
```bash
go build -o kbot cmd/kbot/main.go
```

5. Run the bot:
```bash
./kbot
```

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
go test ./...
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

## Contributing
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Contact
For any questions or issues, please create an issue in the repository. 
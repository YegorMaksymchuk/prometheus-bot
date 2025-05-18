package bot

import (
	"log"
	"os"
	"time"

	tele "gopkg.in/telebot.v4"
)

// Bot represents the Telegram bot instance
type Bot struct {
	bot *tele.Bot
}

// New creates a new bot instance
func New() (*Bot, error) {
	pref := tele.Settings{
		Token:  os.Getenv("TELE_TOKEN"),
		Poller: &tele.LongPoller{Timeout: 10 * time.Second},
	}

	b, err := tele.NewBot(pref)
	if err != nil {
		return nil, err
	}

	return &Bot{bot: b}, nil
}

// logCommand logs command execution details
func (b *Bot) logCommand(c tele.Context, command string) {
	user := c.Sender()
	log.Printf("[%s] Command: %s | User: %s (ID: %d) | Chat: %s (ID: %d)",
		time.Now().Format("2006-01-02 15:04:05"),
		command,
		user.Username,
		user.ID,
		c.Chat().Title,
		c.Chat().ID,
	)
}

// Start initializes and starts the bot
func (b *Bot) Start() {
	// Handle /start command
	b.bot.Handle("/start", func(c tele.Context) error {
		b.logCommand(c, "/start")
		return c.Send("Welcome! I'm your Telegram bot. Use /help to see available commands.")
	})

	// Handle /help command
	b.bot.Handle("/help", func(c tele.Context) error {
		b.logCommand(c, "/help")
		helpText := `Available commands:
/start - Start the bot
/help - Show this help message
/status - Check bot status`
		return c.Send(helpText)
	})

	// Handle /status command
	b.bot.Handle("/status", func(c tele.Context) error {
		b.logCommand(c, "/status")
		return c.Send("Bot is running and healthy!")
	})

	// Handle text messages
	b.bot.Handle(tele.OnText, func(c tele.Context) error {
		msg := c.Text()
		user := c.Sender()
		log.Printf("[%s] Message: %s | User: %s (ID: %d) | Chat: %s (ID: %d)",
			time.Now().Format("2006-01-02 15:04:05"),
			msg,
			user.Username,
			user.ID,
			c.Chat().Title,
			c.Chat().ID,
		)
		return c.Send("I received your message: " + msg)
	})

	log.Println("Bot started...")
	b.bot.Start()
}

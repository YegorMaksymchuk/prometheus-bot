package main

import (
	"log"
	"os"

	"github.com/spf13/cobra"
	"github.com/yehormaksymchuk/bot-telegram/internal/bot"
)

var rootCmd = &cobra.Command{
	Use:   "kbot",
	Short: "A Telegram bot written in Go",
	Long:  `A Telegram bot that handles user messages and responds accordingly.`,
	Run: func(cmd *cobra.Command, args []string) {
		// Check if TELE_TOKEN is set
		if os.Getenv("TELE_TOKEN") == "" {
			log.Fatal("TELE_TOKEN environment variable is not set")
			log.Println("PANIC: TELE_TOKEN environment variable is not set")
			os.Exit(1)
		}

		// Create and start the bot
		b, err := bot.New()
		if err != nil {
			log.Fatalf("Failed to create bot: %v", err)
		}

		b.Start()
	},
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}

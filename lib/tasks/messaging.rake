namespace :messaging do
  namespace :telegram do
    desc "Set Telegram webhook URL. Usage: rails messaging:telegram:set_webhook [URL=https://your-ngrok-url.io]"
    task set_webhook: :environment do
      base_url = ENV["URL"] || Rails.application.config.webhook_base_url
      token = Rails.application.config.telegram_bot_token

      if token.blank?
        puts "❌ TELEGRAM_BOT_TOKEN is not set in .env"
        exit 1
      end

      if base_url.blank?
        puts "❌ Please set WEBHOOK_BASE_URL in .env or pass URL=https://your-url.io"
        exit 1
      end

      webhook_url = "#{base_url}/api/v1/webhooks/telegram/#{token}"
      api_url = "https://api.telegram.org/bot#{token}/setWebhook"

      puts "Setting Telegram webhook to: #{base_url}/api/v1/webhooks/telegram/[TOKEN]"

      response = HTTParty.post(api_url, body: { url: webhook_url })
      result = JSON.parse(response.body)

      if result["ok"]
        puts "✅ Telegram webhook set successfully!"
        puts "   Description: #{result['description']}"
      else
        puts "❌ Failed: #{result['description']}"
      end
    end

    desc "Remove Telegram webhook"
    task remove_webhook: :environment do
      token = Rails.application.config.telegram_bot_token

      if token.blank?
        puts "❌ TELEGRAM_BOT_TOKEN is not set in .env"
        exit 1
      end

      api_url = "https://api.telegram.org/bot#{token}/deleteWebhook"
      response = HTTParty.post(api_url)
      result = JSON.parse(response.body)

      if result["ok"]
        puts "✅ Telegram webhook removed."
      else
        puts "❌ Failed: #{result['description']}"
      end
    end

    desc "Get Telegram webhook info"
    task webhook_info: :environment do
      token = Rails.application.config.telegram_bot_token

      if token.blank?
        puts "❌ TELEGRAM_BOT_TOKEN is not set in .env"
        exit 1
      end

      api_url = "https://api.telegram.org/bot#{token}/getWebhookInfo"
      response = HTTParty.get(api_url)
      result = JSON.parse(response.body)

      puts JSON.pretty_generate(result)
    end

    desc "Register bot commands with Telegram (shows in / menu)"
    task set_commands: :environment do
      token = Rails.application.config.telegram_bot_token

      if token.blank?
        puts "❌ TELEGRAM_BOT_TOKEN is not set in .env"
        exit 1
      end

      commands = [
        { command: "start", description: "Welcome message and get started" },
        { command: "help", description: "Show all available commands" },
        { command: "rewrite", description: "Rewrite a heated message to be calmer" },
        { command: "mediate", description: "Start a conflict mediation session" },
        { command: "myperspective", description: "Add your perspective to mediation" },
        { command: "partnerperspective", description: "Add partner's perspective to mediation" },
        { command: "analyze", description: "Get AI mediation analysis" },
        { command: "persona", description: "Change AI personality style" },
        { command: "language", description: "Switch language (en/hi)" },
        { command: "reset", description: "Start a fresh conversation" }
      ]

      api_url = "https://api.telegram.org/bot#{token}/setMyCommands"
      response = HTTParty.post(api_url,
        headers: { "Content-Type" => "application/json" },
        body: { commands: commands }.to_json
      )
      result = JSON.parse(response.body)

      if result["ok"]
        puts "✅ Bot commands registered!"
        commands.each { |c| puts "   /#{c[:command]} — #{c[:description]}" }
      else
        puts "❌ Failed: #{result['description']}"
      end
    end
  end
end

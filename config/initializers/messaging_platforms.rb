# Messaging Platform Configuration
# Set these in your .env file or environment variables

# Webhook Base URL (ngrok or production)
Rails.application.config.webhook_base_url = ENV.fetch("WEBHOOK_BASE_URL", "")

# Telegram Bot
Rails.application.config.telegram_bot_token = ENV.fetch("TELEGRAM_BOT_TOKEN", "")

# WhatsApp Cloud API (Meta)
Rails.application.config.whatsapp_verify_token = ENV.fetch("WHATSAPP_VERIFY_TOKEN", "")
Rails.application.config.whatsapp_access_token = ENV.fetch("WHATSAPP_ACCESS_TOKEN", "")
Rails.application.config.whatsapp_phone_number_id = ENV.fetch("WHATSAPP_PHONE_NUMBER_ID", "")

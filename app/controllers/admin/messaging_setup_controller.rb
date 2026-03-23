module Admin
  class MessagingSetupController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    def show
      @telegram_configured = Rails.application.config.telegram_bot_token.present?
      @whatsapp_configured = Rails.application.config.whatsapp_access_token.present?
      @webhook_base_url = Rails.application.config.webhook_base_url.presence
    end

    def set_telegram_webhook
      token = Rails.application.config.telegram_bot_token
      base_url = Rails.application.config.webhook_base_url

      if token.blank?
        redirect_to admin_messaging_setup_path, alert: "TELEGRAM_BOT_TOKEN is not set in .env"
        return
      end

      if base_url.blank?
        redirect_to admin_messaging_setup_path, alert: "WEBHOOK_BASE_URL is not set in .env"
        return
      end

      webhook_url = "#{base_url.strip}/api/v1/webhooks/telegram/#{token}"
      api_url = "https://api.telegram.org/bot#{token}/setWebhook"

      response = HTTParty.post(api_url, body: { url: webhook_url })
      result = JSON.parse(response.body)

      if result["ok"]
        redirect_to admin_messaging_setup_path, notice: "Telegram webhook set successfully!"
      else
        redirect_to admin_messaging_setup_path, alert: "Failed to set webhook: #{result['description']}"
      end
    end

    def telegram_webhook_info
      token = Rails.application.config.telegram_bot_token

      if token.blank?
        redirect_to admin_messaging_setup_path, alert: "TELEGRAM_BOT_TOKEN is not set in .env"
        return
      end

      api_url = "https://api.telegram.org/bot#{token}/getWebhookInfo"
      response = HTTParty.get(api_url)
      @webhook_info = JSON.parse(response.body)

      redirect_to admin_messaging_setup_path, notice: "Telegram webhook: #{@webhook_info.dig('result', 'url').presence || 'Not set'}"
    end

    private

    def require_admin!
      unless current_user.admin?
        redirect_to root_path, alert: "Access denied."
      end
    end
  end
end

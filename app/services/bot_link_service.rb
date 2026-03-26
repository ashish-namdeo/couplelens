class BotLinkService
  def initialize(user)
    @user = user
  end

  # Send link invitation to WhatsApp
  def send_whatsapp_invitation(phone_number)
    phone = sanitize_phone(phone_number)
    return { success: false, error: "Invalid phone number" } if phone.blank?

    token = Rails.application.config.whatsapp_access_token
    phone_number_id = Rails.application.config.whatsapp_phone_number_id

    if token.blank? || phone_number_id.blank?
      return { success: false, error: "WhatsApp not configured" }
    end

    # Store pending link info
    @user.update!(
      bot_link_code: "WA-LINK-#{SecureRandom.hex(4)}",
      bot_link_code_expires_at: 30.minutes.from_now
    )

    # Send interactive button message
    url = "https://graph.facebook.com/v22.0/#{phone_number_id}/messages"
    body = {
      messaging_product: "whatsapp",
      to: phone,
      type: "interactive",
      interactive: {
        type: "button",
        body: {
          text: "👋 Hi! *#{@user.first_name}* wants to link their CoupleLens account with this WhatsApp number.\n\nTap 'Confirm' to connect your account and start using CoupleLens via WhatsApp."
        },
        action: {
          buttons: [
            { type: "reply", reply: { id: "confirm_link_#{@user.id}", title: "✅ Confirm Link" } },
            { type: "reply", reply: { id: "reject_link", title: "❌ Cancel" } }
          ]
        }
      }
    }.to_json

    response = HTTParty.post(url,
      headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" },
      body: body
    )

    result = JSON.parse(response.body)
    if result["error"]
      Rails.logger.error("WhatsApp link invitation error: #{result['error']['message']}")
      error_msg = if result["error"]["code"] == 131030
                    "This number hasn't messaged the CoupleLens bot yet. Please send 'hi' to the bot first, then try again."
                  else
                    result["error"]["message"]
                  end
      { success: false, error: error_msg }
    else
      { success: true, message: "Link invitation sent to WhatsApp! Check your messages and tap Confirm." }
    end
  rescue StandardError => e
    Rails.logger.error("WhatsApp link service error: #{e.message}")
    { success: false, error: "Failed to send invitation. Please try again." }
  end

  # Send link invitation to Telegram
  def send_telegram_invitation(telegram_username_or_id)
    chat_id = telegram_username_or_id.to_s.strip.delete("@")
    return { success: false, error: "Please enter a valid Telegram chat ID" } if chat_id.blank?

    token = Rails.application.config.telegram_bot_token
    return { success: false, error: "Telegram bot not configured" } if token.blank?

    # Store pending link info
    @user.update!(
      bot_link_code: "TG-LINK-#{SecureRandom.hex(4)}",
      bot_link_code_expires_at: 30.minutes.from_now
    )

    url = "https://api.telegram.org/bot#{token}/sendMessage"
    body = {
      chat_id: chat_id,
      text: "👋 Hi! *#{@user.first_name}* wants to link their CoupleLens account with this Telegram.\n\nTap 'Confirm' to connect your account and start using CoupleLens via Telegram.",
      parse_mode: "Markdown",
      reply_markup: {
        inline_keyboard: [
          [
            { text: "✅ Confirm Link", callback_data: "/confirm_link #{@user.id}" },
            { text: "❌ Cancel", callback_data: "/reject_link" }
          ]
        ]
      }.to_json
    }

    response = HTTParty.post(url, body: body, timeout: 30)
    result = JSON.parse(response.body)

    if result["ok"]
      { success: true, message: "Link invitation sent to Telegram! Check your messages and tap Confirm." }
    else
      error_msg = if result["description"]&.include?("chat not found")
                    "Chat not found. Please start a conversation with the bot first by sending /start, then try again."
                  else
                    result["description"] || "Failed to send message"
                  end
      { success: false, error: error_msg }
    end
  rescue StandardError => e
    Rails.logger.error("Telegram link service error: #{e.message}")
    { success: false, error: "Failed to send invitation. Please try again." }
  end

  private

  def sanitize_phone(phone)
    cleaned = phone.to_s.gsub(/[\s\-\(\)]/, "")
    cleaned = cleaned.delete("+")
    # Must be digits only and at least 10 chars
    cleaned.match?(/\A\d{10,15}\z/) ? cleaned : nil
  end
end

class BrevoEmailService
  BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"

  def self.send_email(to:, subject:, html:, from_name: "CoupleLens", from_email: nil)
    from_email ||= ENV.fetch("BREVO_FROM_EMAIL", "noreply@sendinblue.com")
    api_key = ENV["BREVO_API_KEY"]

    if api_key.blank?
      Rails.logger.error("BREVO_API_KEY is not set")
      return false
    end

    response = HTTParty.post(
      BREVO_API_URL,
      headers: {
        "api-key" => api_key,
        "Content-Type" => "application/json"
      },
      body: {
        sender: { name: from_name, email: from_email },
        to: [{ email: to }],
        subject: subject,
        htmlContent: html
      }.to_json
    )

    if response.success?
      Rails.logger.info("Brevo email sent successfully to #{to}")
      true
    else
      Rails.logger.error("Brevo email failed: #{response.code} - #{response.body}")
      false
    end
  rescue StandardError => e
    Rails.logger.error("Brevo email service error: #{e.message}")
    false
  end
end

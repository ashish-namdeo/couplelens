class ResendEmailService
  RESEND_API_URL = "https://api.resend.com/emails"

  def self.send_email(to:, subject:, html:, from: nil)
    from ||= ENV.fetch("RESEND_FROM_EMAIL", "onboarding@resend.dev")

    response = HTTParty.post(
      RESEND_API_URL,
      headers: {
        "Authorization" => "Bearer #{ENV['RESEND_API_KEY']}",
        "Content-Type" => "application/json"
      },
      body: {
        from: from,
        to: [to],
        subject: subject,
        html: html
      }.to_json
    )

    unless response.success?
      Rails.logger.error("Resend email failed: #{response.code} - #{response.body}")
      raise "Email delivery failed: #{response.body}"
    end

    response
  end
end

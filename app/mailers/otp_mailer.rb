class OtpMailer < ApplicationMailer
  default from: ENV.fetch("BREVO_FROM_EMAIL", "noreply@sendinblue.com")

  def send_otp(user)
    @user = user
    @otp_code = user.otp_code
    
    # In production, use Brevo API directly (bypasses SMTP timeout issues)
    if Rails.env.production?
      html = ApplicationController.renderer.render(
        template: "otp_mailer/send_otp",
        layout: "mailer",
        assigns: { user: @user, otp_code: @otp_code }
      )
      
      BrevoEmailService.send_email(
        to: @user.email,
        subject: "Your CoupleLens Login OTP",
        html: html
      )
    else
      # In development, use ActionMailer with letter_opener
      mail(to: @user.email, subject: "Your CoupleLens Login OTP")
    end
  end
end

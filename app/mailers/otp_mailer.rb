class OtpMailer < ApplicationMailer
  default from: ENV.fetch("BREVO_FROM_EMAIL", "noreply@sendinblue.com")

  def send_otp(user)
    @user = user
    @otp_code = user.otp_code
    mail(to: @user.email, subject: "Your CoupleLens Login OTP")
  end
end

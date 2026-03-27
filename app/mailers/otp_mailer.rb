class OtpMailer < ApplicationMailer
  default from: ENV.fetch("RESEND_FROM_EMAIL", "onboarding@resend.dev")

  def send_otp(user)
    @user = user
    @otp_code = user.otp_code
    mail(to: @user.email, subject: "Your CoupleLens Login OTP")
  end
end

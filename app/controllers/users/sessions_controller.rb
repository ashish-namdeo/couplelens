class Users::SessionsController < Devise::SessionsController
  def create
    user = User.find_by(email: sign_in_params[:email])

    if user&.valid_password?(sign_in_params[:password])
      # Generate and send OTP
      otp = SecureRandom.random_number(100_000..999_999).to_s
      user.update!(otp_code: otp, otp_sent_at: Time.current, otp_verified: false)
      send_otp_email(user)

      # Store user ID in session for OTP verification step
      session[:otp_user_id] = user.id
      session[:otp_remember_me] = sign_in_params[:remember_me]

      redirect_to users_otp_verify_path, status: :see_other
    else
      # Let Devise handle invalid credentials normally
      self.resource = resource_class.new(sign_in_params)
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def send_otp_email(user)
    html = ApplicationController.renderer.render(
      template: "otp_mailer/send_otp",
      layout: "mailer",
      assigns: { user: user, otp_code: user.otp_code }
    )
    Thread.new do
      ResendEmailService.send_email(
        to: user.email,
        subject: "Your CoupleLens Login OTP",
        html: html
      )
    rescue => e
      Rails.logger.error("OTP email failed: #{e.message}")
    end
  end
end

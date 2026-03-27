class Users::SessionsController < Devise::SessionsController
  def create
    user = User.find_by(email: sign_in_params[:email])

    if user&.valid_password?(sign_in_params[:password])
      # OTP disabled until email service is configured
      sign_in(user)
      user.remember_me! if sign_in_params[:remember_me] == "1"
      redirect_to after_sign_in_path_for(user), notice: "Signed in successfully.", status: :see_other
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

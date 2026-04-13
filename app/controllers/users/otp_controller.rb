class Users::OtpController < ApplicationController
  # GET /users/otp/verify
  def verify
    unless session[:otp_user_id]
      redirect_to new_user_session_path, alert: "Please sign in first.", status: :see_other
      return
    end

    @user = User.find_by(id: session[:otp_user_id])
    unless @user
      session.delete(:otp_user_id)
      redirect_to new_user_session_path, alert: "Session expired. Please sign in again.", status: :see_other
    end
  end

  # POST /users/otp/confirm
  def confirm
    user = User.find_by(id: session[:otp_user_id])

    unless user
      redirect_to new_user_session_path, alert: "Session expired. Please sign in again.", status: :see_other
      return
    end

    # Check OTP expiry (5 minutes)
    if user.otp_sent_at.blank? || user.otp_sent_at < 5.minutes.ago
      session.delete(:otp_user_id)
      redirect_to new_user_session_path, alert: "OTP expired. Please sign in again.", status: :see_other
      return
    end

    if ActiveSupport::SecurityUtils.secure_compare(user.otp_code.to_s, params[:otp_code].to_s.strip)
      # OTP verified — clear OTP and sign in
      user.update!(otp_code: nil, otp_sent_at: nil, otp_verified: true)
      remember_me = session.delete(:otp_remember_me)
      session.delete(:otp_user_id)

      sign_in(user)
      user.remember_me! if remember_me == "1"

      redirect_to after_sign_in_path_for(user), status: :see_other
    else
      flash.now[:alert] = "Invalid OTP. Please try again."
      @user = user
      render :verify, status: :unprocessable_entity
    end
  end

  # POST /users/otp/resend
  def resend
    user = User.find_by(id: session[:otp_user_id])

    unless user
      redirect_to new_user_session_path, alert: "Session expired. Please sign in again.", status: :see_other
      return
    end

    # Rate limit: allow resend only after 60 seconds
    if user.otp_sent_at.present? && user.otp_sent_at > 60.seconds.ago
      redirect_to users_otp_verify_path, alert: "Please wait before requesting a new OTP.", status: :see_other
      return
    end

    otp = SecureRandom.random_number(100_000..999_999).to_s
    user.update!(otp_code: otp, otp_sent_at: Time.current, otp_verified: false)
    send_otp_email(user)

    redirect_to users_otp_verify_path, notice: "A new OTP has been sent to your email.", status: :see_other
  end

  private

  def after_sign_in_path_for(resource)
    dashboard_path
  end

  def send_otp_email(user)
    # Use ActionMailer which respects environment settings (letter_opener in dev, Brevo in prod)
    OtpMailer.send_otp(user).deliver_now
  rescue => e
    Rails.logger.error("OTP email failed: #{e.message}")
  end
end

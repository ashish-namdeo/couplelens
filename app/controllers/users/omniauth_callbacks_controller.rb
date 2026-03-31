class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env['omniauth.auth']
    role = request.env['omniauth.params']&.dig('role')

    @user = User.from_omniauth(auth, role: role)

    if @user.persisted?
      sign_in @user, event: :authentication
      set_flash_message(:notice, :success, kind: 'Google') if is_navigational_format?

      if @user.therapist?
        if @user.therapist_profile.present?
          redirect_to therapist_dashboard_path
        else
          redirect_to dashboard_path
        end
      else
        redirect_to dashboard_path
      end
    else
      session['devise.google_data'] = auth.except('extra')
      flash[:alert] = @user.errors.full_messages.join("\n")
      redirect_to new_user_session_url
    end
  end

  def failure
    redirect_to root_path, alert: 'Authentication failed. Please try again.'
  end
end

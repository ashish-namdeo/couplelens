class Users::RegistrationsController < Devise::RegistrationsController
  protected

  def after_sign_up_path_for(_resource)
    sign_out(resource)
    flash[:notice] = "Account created successfully! Please sign in."
    new_user_session_path
  end
end

class Users::RegistrationsController < Devise::RegistrationsController
  protected

  def update_resource(resource, params)
    remove_profile_image_if_requested(resource, params)

    if resource.oauth_user? && params[:password].blank? && params[:password_confirmation].blank?
      resource.update_without_password(params.except(:current_password))
    else
      super
    end
  end

  def after_sign_up_path_for(_resource)
    sign_out(resource)
    new_user_session_path
  end

  def remove_profile_image_if_requested(resource, params)
    remove_flag = params.delete(:remove_profile_image) || params.delete("remove_profile_image")
    remove_requested = ActiveModel::Type::Boolean.new.cast(remove_flag)
    resource.profile_image.purge if remove_requested && resource.profile_image.attached?
  end
end

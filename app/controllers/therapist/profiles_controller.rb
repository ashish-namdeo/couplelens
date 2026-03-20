module Therapist
  class ProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_therapist!

    def edit
      @profile = current_user.therapist_profile
    end

    def update
      @profile = current_user.therapist_profile
      if @profile.update(profile_params)
        redirect_to therapist_dashboard_path, notice: 'Profile updated successfully!'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def require_therapist!
      unless current_user.therapist?
        redirect_to root_path, alert: 'Access denied.'
      end
    end

    def profile_params
      params.require(:therapist_profile).permit(:bio, :specialization, :hourly_rate, :certifications)
    end
  end
end

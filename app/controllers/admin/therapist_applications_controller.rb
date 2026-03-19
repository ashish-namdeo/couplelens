module Admin
  class TherapistApplicationsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    def index
      @applications = TherapistApplication.order(created_at: :desc)
    end

    def show
      @application = TherapistApplication.find(params[:id])
    end

    def approve
      @application = TherapistApplication.find(params[:id])
      @application.update!(status: :approved)

      # Create therapist profile
      user = @application.user
      user.update!(role: :therapist)
      TherapistProfile.create!(
        user: user,
        specialization: @application.specialization,
        bio: @application.bio,
        hourly_rate: @application.hourly_rate,
        years_experience: @application.years_experience,
        certifications: @application.certifications,
        status: :approved
      )

      redirect_to admin_therapist_applications_path, notice: 'Application approved!'
    end

    def reject
      @application = TherapistApplication.find(params[:id])
      @application.update!(status: :rejected, admin_notes: params[:admin_notes])
      redirect_to admin_therapist_applications_path, notice: 'Application rejected.'
    end

    private

    def require_admin!
      unless current_user.admin?
        redirect_to root_path, alert: 'Access denied.'
      end
    end
  end
end

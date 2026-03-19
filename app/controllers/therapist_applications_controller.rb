class TherapistApplicationsController < ApplicationController
  before_action :authenticate_user!

  def new
    @application = current_user.build_therapist_application
  end

  def create
    @application = current_user.build_therapist_application(application_params)

    if @application.save
      redirect_to root_path, notice: 'Application submitted! We will review it shortly.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def application_params
    params.require(:therapist_application).permit(:full_name, :email, :specialization, :bio, :certifications, :years_experience, :hourly_rate)
  end
end

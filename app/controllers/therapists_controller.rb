class TherapistsController < ApplicationController
  before_action :authenticate_user!

  def index
    @therapists = TherapistProfile.approved.includes(:user)

    if params[:specialization].present?
      @therapists = @therapists.by_specialization(params[:specialization])
    end

    @specializations = TherapistProfile::SPECIALIZATIONS
  end

  def show
    @therapist = TherapistProfile.approved.find(params[:id])
    @booking = Booking.new
  end
end

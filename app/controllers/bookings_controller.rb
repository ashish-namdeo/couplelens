class BookingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @upcoming_bookings = current_user.bookings.upcoming.includes(therapist_profile: :user)
    @past_bookings = current_user.bookings.past.includes(therapist_profile: :user)
  end

  def create
    @therapist = TherapistProfile.approved.find(params[:therapist_id])
    @booking = current_user.bookings.new(booking_params)
    @booking.therapist_profile = @therapist
    @booking.amount = @therapist.hourly_rate

    if @booking.save
      redirect_to bookings_path, notice: 'Booking request submitted!'
    else
      redirect_to therapist_path(@therapist), alert: 'Could not create booking. Please check the details.'
    end
  end

  def cancel
    @booking = current_user.bookings.find(params[:id])
    @booking.update(status: :cancelled)
    redirect_to bookings_path, notice: 'Booking cancelled.'
  end

  private

  def booking_params
    params.require(:booking).permit(:scheduled_at, :session_type, :notes, :duration)
  end
end

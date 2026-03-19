module Admin
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    def show
      @total_users = User.couple_member.count
      @total_therapists = User.therapist.count
      @pending_applications = TherapistApplication.submitted.count
      @total_bookings = Booking.count
      @total_revenue = Booking.completed.sum(:amount)
      @recent_applications = TherapistApplication.order(created_at: :desc).limit(10)
    end

    private

    def require_admin!
      unless current_user.admin?
        redirect_to root_path, alert: 'Access denied.'
      end
    end
  end
end

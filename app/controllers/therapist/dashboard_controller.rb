module Therapist
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :require_therapist!

    def show
      @profile = current_user.therapist_profile
      @upcoming_bookings = @profile.bookings.upcoming.includes(:user).limit(5)
      @past_bookings = @profile.bookings.past.includes(:user).limit(5)
      @total_sessions = @profile.bookings.completed.count
      @total_clients = @profile.bookings.select(:user_id).distinct.count
      @total_revenue = @profile.bookings.completed.sum(:amount)
      @pending_bookings = @profile.bookings.pending.count
    end

    private

    def require_therapist!
      unless current_user.therapist?
        redirect_to root_path, alert: 'Access denied. Therapist account required.'
      end
    end
  end
end

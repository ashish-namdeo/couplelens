class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    return redirect_to admin_dashboard_path if current_user.admin?
    return redirect_to therapist_dashboard_path if current_user.therapist?

    # Pending therapist applicant — show waiting page
    if current_user.therapist_application&.submitted?
      @application = current_user.therapist_application
      return render 'dashboard/therapist_pending'
    end

    @recent_conversations = current_user.conversations.order(updated_at: :desc).limit(3)
    @health_metrics = current_user.health_metrics.recent.limit(10)
    @upcoming_bookings = current_user.bookings.upcoming.limit(3)
    @recent_memories = current_user.memories.recent.limit(5)
    @active_programs = current_user.user_programs.where(status: [:enrolled, :in_progress]).includes(:program).limit(3)

    # Dashboard stats
    @total_conversations = current_user.conversations.count
    @total_sessions = current_user.bookings.completed.count
    @avg_health_score = current_user.health_metrics.average(:score)&.round(1) || 0
    @memories_count = current_user.memories.count
  end
end

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

    @recent_conversations = current_user.conversations.where(platform: 'web').order(updated_at: :desc).limit(3)
    @telegram_conversations = current_user.conversations.by_platform('telegram').order(updated_at: :desc).limit(5)
    @whatsapp_conversations = current_user.conversations.by_platform('whatsapp').order(updated_at: :desc).limit(5)
    @health_metrics = current_user.health_metrics.recent.limit(10)
    @upcoming_bookings = current_user.bookings.upcoming.limit(3)
    @recent_memories = current_user.memories.recent.limit(5)
    @active_programs = current_user.user_programs.where(status: [:enrolled, :in_progress]).includes(:program).limit(3)

    # Dashboard stats
    @total_conversations = current_user.conversations.count
    @total_sessions = current_user.bookings.completed.count
    @avg_health_score = current_user.health_metrics.average(:score)&.round(1) || 0
    @memories_count = current_user.memories.count

    # Bot link status
    @bot_linked = current_user.bot_linked?
  end

  def generate_bot_link_code
    code = current_user.generate_bot_link_code!
    render json: { code: code, expires_in: "30 minutes" }
  end

  def generate_telegram_link
    # Generate a link code and return Telegram deep link
    code = "TG-LINK-#{SecureRandom.hex(4)}"
    current_user.update!(
      bot_link_code: code,
      bot_link_code_expires_at: 30.minutes.from_now
    )
    bot_username = Rails.application.config.telegram_bot_username
    deep_link = "https://t.me/#{bot_username}?start=LINK_#{current_user.id}"
    render json: { success: true, link: deep_link }
  end

  def send_link_invitation
    platform = params[:platform]
    service = BotLinkService.new(current_user)

    result = case platform
             when "whatsapp"
               service.send_whatsapp_invitation(params[:phone_number])
             when "telegram"
               service.send_telegram_invitation(params[:telegram_chat_id])
             else
               { success: false, error: "Invalid platform" }
             end

    # Normalize response: always use :message key for the JS frontend
    result[:message] ||= result.delete(:error)
    render json: result
  end
end

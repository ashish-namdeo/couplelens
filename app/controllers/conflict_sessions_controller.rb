class ConflictSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conflict_session, only: [:show, :update, :analyze]

  def index
    @conflict_sessions = current_user.conflict_sessions.order(created_at: :desc)
  end

  def show; end

  def new
    @conflict_session = current_user.conflict_sessions.new
  end

  def create
    @conflict_session = current_user.conflict_sessions.new(conflict_session_params)

    if @conflict_session.save
      redirect_to @conflict_session
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @conflict_session.update(conflict_session_params)
      redirect_to @conflict_session
    else
      render :show, status: :unprocessable_entity
    end
  end

  def analyze
    has_perspectives = @conflict_session.user_perspective.present? && @conflict_session.partner_perspective.present?
    has_screenshots = @conflict_session.chat_screenshots.attached?

    if has_perspectives || has_screenshots
      analysis = generate_mediation_analysis(@conflict_session)
      @conflict_session.update!(
        ai_analysis: analysis[:analysis],
        ai_summary: analysis[:summary],
        status: :completed
      )
      if analysis[:analysis].include?("We encountered an issue")
        redirect_to @conflict_session, alert: 'AI analysis failed. Please try again.'
      else
        redirect_to @conflict_session
      end
    else
      redirect_to @conflict_session, alert: 'Please provide both perspectives or upload chat screenshots before analysis.'
    end
  end

  private

  def set_conflict_session
    @conflict_session = current_user.conflict_sessions.find(params[:id])
  end

  def conflict_session_params
    params.require(:conflict_session).permit(:topic, :user_perspective, :partner_perspective, :partner_name, :language, chat_screenshots: [])
  end

  def generate_mediation_analysis(session)
    gemini = GeminiService.new

    # Collect image data if screenshots are attached
    image_data = []
    if session.chat_screenshots.attached?
      session.chat_screenshots.each do |screenshot|
        image_data << {
          base64: Base64.strict_encode64(screenshot.download),
          mime_type: screenshot.content_type
        }
      end
    end

    gemini.mediate_conflict(
      topic: session.topic,
      user_name: session.user.first_name,
      partner_name: session.partner_name,
      user_perspective: session.user_perspective,
      partner_perspective: session.partner_perspective,
      language: session.language || 'english',
      images: image_data
    )
  rescue StandardError => e
    Rails.logger.error("Gemini mediation error: #{e.message}")
    language = session.language || 'english'
    if language == 'hindi'
      {
        analysis: "हमें AI विश्लेषण उत्पन्न करने में समस्या हुई। कृपया पुनः प्रयास करें।",
        summary: "विश्लेषण अस्थायी रूप से अनुपलब्ध है। कृपया पुनः प्रयास करें।"
      }
    else
      {
        analysis: "We encountered an issue generating the AI analysis. Please try again.",
        summary: "Analysis temporarily unavailable. Please retry."
      }
    end
  end
end

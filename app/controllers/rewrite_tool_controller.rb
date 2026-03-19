class RewriteToolController < ApplicationController
  before_action :authenticate_user!

  def index; end

  def rewrite
    original_message = params[:original_message]

    if original_message.blank?
      @error = "Please enter a message to rewrite."
      render :index
      return
    end

    @original = original_message
    @rewritten = generate_rewrite(original_message)
    @tone_analysis = analyze_tone(original_message)

    render :index
  end

  private

  def generate_rewrite(message)
    gemini = GeminiService.new
    result = gemini.rewrite_message(message)
    @tone_analysis = result[:tone_analysis]
    result[:rewritten]
  rescue StandardError => e
    Rails.logger.error("Gemini rewrite error: #{e.message}")
    @tone_analysis = default_tone
    "I want to share something important with you. #{message.sub(/^./, &:downcase)} I value our relationship and want us to work through this together."
  end

  def analyze_tone(message)
    # Tone is now set by generate_rewrite via Gemini; this is a fallback
    @tone_analysis || default_tone
  end

  def default_tone
    {
      original_tone: "Unknown",
      emotional_intensity: 50,
      defensiveness_risk: 50,
      constructiveness: 50,
      suggested_approach: "Express feelings using 'I' statements, acknowledge your partner's perspective, and focus on the specific behavior rather than character judgments."
    }
  end
end

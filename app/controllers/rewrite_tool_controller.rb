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
    @language = params[:language] || 'english'
    @rewritten = generate_rewrite(original_message, @language)

    render :index
  end

  private

  def generate_rewrite(message, language = 'english')
    gemini = GeminiService.new
    result = gemini.rewrite_message(message, language: language)
    @tone_analysis = result[:tone_analysis]
    result[:rewritten]
  rescue Faraday::TooManyRequestsError
    @tone_analysis = default_tone(language: language)
    @rate_limit_error = true
    if language == 'hindi'
      "हम अभी इस संदेश को पुनः लिखने में असमर्थ हैं। कृपया कुछ देर बाद पुनः प्रयास करें।"
    else
      "We are unable to rewrite this message right now. Please try again in a few moments."
    end
  rescue StandardError => e
    Rails.logger.error("Gemini rewrite error: #{e.message}")
    @tone_analysis = default_tone(language: language)
    @rate_limit_error = true
    if language == 'hindi'
      "हम अभी इस संदेश को पुनः लिखने में असमर्थ हैं। कृपया कुछ देर बाद पुनः प्रयास करें।"
    else
      "We are unable to rewrite this message right now. Please try again in a few moments."
    end
  end

  def analyze_tone(message)
    # Tone is now set by generate_rewrite via Gemini; this is a fallback
    @tone_analysis || default_tone(language: @language || 'english')
  end

  def default_tone(language: 'english')
    if language == 'hindi'
      {
        original_tone: "अज्ञात",
        emotional_intensity: 50,
        defensiveness_risk: 50,
        constructiveness: 50,
        suggested_approach: "'मैं' कथनों का उपयोग करें, अपने साथी के दृष्टिकोण को स्वीकार करें, और विशिष्ट व्यवहार पर ध्यान दें।"
      }
    else
      {
        original_tone: "Unknown",
        emotional_intensity: 50,
        defensiveness_risk: 50,
        constructiveness: 50,
        suggested_approach: "Express feelings using 'I' statements, acknowledge your partner's perspective, and focus on specific behavior rather than character judgments."
      }
    end
  end
end

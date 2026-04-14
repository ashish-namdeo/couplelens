class MessagesController < ApplicationController
  before_action :authenticate_user!

  def create
    @conversation = current_user.conversations.find(params[:conversation_id])
    @message = @conversation.messages.new(message_params)
    @message.role = 'user'

    if @message.save
      generate_ai_response(@conversation)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @conversation }
      end
    else
      redirect_to @conversation, alert: 'Message could not be sent.'
    end
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end

  def generate_ai_response(conversation)
    # Build message history for Gemini (system + user/assistant messages)
    chat_messages = conversation.messages.ordered.map do |msg|
      { role: msg.role, content: msg.content }
    end

    gemini = GeminiService.new
    response = gemini.chat(chat_messages, language: conversation.language || 'english')

    conversation.messages.create!(
      role: 'assistant',
      content: response
    )
  rescue StandardError => e
    Rails.logger.error("Gemini API error: #{e.message}")
    fallback_message = if conversation.language == 'hindi'
      "मुझे अभी कनेक्ट करने में कठिनाई हो रही है। कृपया कुछ देर में फिर से प्रयास करें।"
    else
      "I'm sorry, I'm having trouble connecting right now. Please try again in a moment."
    end
    conversation.messages.create!(
      role: 'assistant',
      content: fallback_message
    )
  end
end

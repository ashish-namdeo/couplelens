class MessagesController < ApplicationController
  before_action :authenticate_user!

  def create
    @conversation = current_user.conversations.find(params[:conversation_id])
    @message = @conversation.messages.new(message_params)
    @message.role = 'user'

    if @message.save
      generate_ai_response(@conversation)
      redirect_to @conversation
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
    response = gemini.chat(chat_messages)

    conversation.messages.create!(
      role: 'assistant',
      content: response
    )
  rescue StandardError => e
    Rails.logger.error("Gemini API error: #{e.message}")
    conversation.messages.create!(
      role: 'assistant',
      content: "I'm sorry, I'm having trouble connecting right now. Please try again in a moment."
    )
  end
end

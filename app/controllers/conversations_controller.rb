class ConversationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation, only: [:show, :destroy]

  def index
    @conversations = current_user.conversations.order(updated_at: :desc)
  end

  def show
    @messages = @conversation.messages.ordered
    @message = Message.new
  end

  def new
    @conversation = current_user.conversations.new
  end

  def create
    @conversation = current_user.conversations.new(conversation_params)
    @conversation.title = "New Conversation #{Time.current.strftime('%b %d, %H:%M')}" if @conversation.title.blank?

    if @conversation.save
      # Add system message based on persona
      system_prompt = persona_system_prompt(@conversation.persona)
      @conversation.messages.create!(role: 'system', content: system_prompt)

      redirect_to @conversation, notice: 'Conversation started!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @conversation.destroy
    redirect_to conversations_path, notice: 'Conversation deleted.'
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:id])
  end

  def conversation_params
    params.require(:conversation).permit(:title, :persona)
  end

  def persona_system_prompt(persona)
    case persona
    when 'clinical_psychologist'
      "You are a clinical psychologist specializing in couples therapy. You provide evidence-based insights, draw from attachment theory and the Gottman Method, and help couples understand the psychological patterns in their relationship. Be professional yet warm."
    when 'empathetic_listener'
      "You are an empathetic listener and relationship companion. You focus on emotional validation, active listening, and creating a safe space for expression. You gently guide conversations toward understanding and healing."
    when 'relationship_coach'
      "You are a proactive relationship coach. You focus on actionable strategies, goal-setting, and accountability. You help couples build positive habits and work toward concrete relationship improvements."
    when 'communication_expert'
      "You are a communication expert specializing in couples dynamics. You analyze language patterns, teach nonviolent communication techniques, and help couples express needs effectively without triggering defensiveness."
    else
      "You are a helpful AI relationship assistant. You provide thoughtful, balanced advice to help couples strengthen their relationship."
    end
  end
end

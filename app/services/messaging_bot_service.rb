class MessagingBotService
  COMMANDS = {
    "/start" => :handle_start,
    "/help" => :handle_help,
    "/rewrite" => :handle_rewrite,
    "/persona" => :handle_persona,
    "/reset" => :handle_reset,
    "/mediate" => :handle_mediate,
    "/myperspective" => :handle_my_perspective,
    "/partnerperspective" => :handle_partner_perspective,
    "/analyze" => :handle_analyze,
    "/language" => :handle_language
  }.freeze

  def initialize(platform:)
    @platform = platform # :telegram or :whatsapp
    @gemini = GeminiService.new
  end

  def process_message(platform_user_id:, text:, user_name: nil)
    user = find_or_create_user(platform_user_id, user_name)
    command, args = parse_command(text)

    if command && COMMANDS.key?(command)
      send(COMMANDS[command], user, args)
    elsif text.start_with?("/rewrite ")
      handle_rewrite(user, text.sub("/rewrite ", ""))
    elsif text.start_with?("/mediate ")
      handle_mediate(user, text.sub("/mediate ", ""))
    elsif text.start_with?("/myperspective ")
      handle_my_perspective(user, text.sub("/myperspective ", ""))
    elsif text.start_with?("/partnerperspective ")
      handle_partner_perspective(user, text.sub("/partnerperspective ", ""))
    else
      handle_chat(user, text)
    end
  end

  def process_photo(platform_user_id:, image_data:, caption: "", user_name: nil)
    user = find_or_create_user(platform_user_id, user_name)

    session = user.conflict_sessions.where.not(status: :completed).order(created_at: :desc).first

    unless session
      return <<~MSG
        📸 To use screenshots, first start a mediation session:
        /mediate <topic>

        Then send your chat screenshots and I'll include them in the analysis.
      MSG
    end

    # Store image data in the session via Active Storage
    filename = "screenshot_#{Time.current.to_i}_#{SecureRandom.hex(4)}.jpg"
    session.chat_screenshots.attach(
      io: StringIO.new(Base64.decode64(image_data[:base64])),
      filename: filename,
      content_type: image_data[:mime_type]
    )

    count = session.chat_screenshots.count

    <<~MSG
      📸 Screenshot #{count} attached to mediation session!
      Topic: #{session.topic}

      You can:
      • Send more screenshots
      • Add perspectives with /myperspective and /partnerperspective
      • Type /analyze when ready (screenshots + perspectives will be analyzed together)
    MSG
  rescue StandardError => e
    Rails.logger.error("Photo processing error: #{e.message}")
    "Sorry, I couldn't process that image. Please try again."
  end

  def process_text_file(platform_user_id:, text_content:, filename: "file.txt", user_name: nil)
    user = find_or_create_user(platform_user_id, user_name)

    session = user.conflict_sessions.where.not(status: :completed).order(created_at: :desc).first

    unless session
      return <<~MSG
        📄 To use text files, first start a mediation session:
        /mediate <topic>

        Then send your .txt file with perspectives.
      MSG
    end

    # Parse the text file — look for labeled sections or use as user perspective
    content = text_content.strip

    if content.match?(/partner('s)?\s*(perspective|side|view)/i)
      # File contains partner perspective
      session.update!(partner_perspective: content)
      reply = "📄 Partner's perspective loaded from #{filename}!"
    elsif content.match?(/my\s*(perspective|side|view)/i)
      # File contains user perspective
      session.update!(user_perspective: content)
      reply = "📄 Your perspective loaded from #{filename}!"
    else
      # Default: save as user perspective
      session.update!(user_perspective: content)
      reply = "📄 Text loaded from #{filename} as your perspective!"
    end

    if session.user_perspective.present? && session.user_perspective != "(pending)" && session.partner_perspective.present?
      reply += "\nBoth perspectives are ready. Type /analyze to get AI mediation."
    else
      reply += "\nYou can also send another .txt for the other perspective, or type /analyze."
    end

    reply
  rescue StandardError => e
    Rails.logger.error("Text file processing error: #{e.message}")
    "Sorry, I couldn't process that file. Please try again."
  end

  private

  def find_or_create_user(platform_user_id, user_name)
    field = platform_field
    user = User.find_by(field => platform_user_id.to_s)

    unless user
      name_parts = (user_name || "User").split(" ", 2)
      user = User.create!(
        field => platform_user_id.to_s,
        email: "#{@platform}_#{platform_user_id}@couplelens.bot",
        password: SecureRandom.hex(16),
        first_name: name_parts[0] || "User",
        last_name: name_parts[1] || @platform.to_s.capitalize,
        role: :couple_member
      )
    end

    user
  end

  def platform_field
    case @platform
    when :telegram then :telegram_id
    when :whatsapp then :whatsapp_id
    end
  end

  def parse_command(text)
    return [nil, nil] unless text.start_with?("/")
    parts = text.split(" ", 2)
    [parts[0].downcase, parts[1]]
  end

  def handle_start(user, _args)
    <<~MSG
      Welcome to CoupleLens! 💑

      I'm your AI relationship assistant. Here's what I can do:

      💬 *Chat* — Just send me a message and I'll help with relationship advice
      ✏️ */rewrite <message>* — Rewrite a heated message to be calmer
      ⚖️ */mediate <topic>* — Start a conflict mediation session
      � */language <en|hi>* — Switch language (English/Hindi)
      �🎭 */persona <type>* — Change my personality:
         • clinical_psychologist
         • empathetic_listener
         • relationship_coach
         • communication_expert
      🔄 */reset* — Start a fresh conversation
      ❓ */help* — Show this menu again

      Let's start! What's on your mind?
    MSG
  end

  def handle_help(user, _args)
    handle_start(user, nil)
  end

  def handle_language(user, args)
    valid = { "en" => "english", "english" => "english", "hi" => "hindi", "hindi" => "hindi" }
    lang_key = args&.strip&.downcase

    if lang_key.blank? || !valid.key?(lang_key)
      conversation = active_conversation(user)
      current = conversation.language || "english"
      return <<~MSG
        🌐 Current language: *#{current.capitalize}*

        Switch with:
        • /language en — English
        • /language hi — Hindi (हिंदी)
      MSG
    end

    language = valid[lang_key]
    conversation = active_conversation(user)
    conversation.update!(language: language)

    if language == "hindi"
      "🌐 भाषा हिंदी में बदल दी गई है! अब मैं हिंदी में जवाब दूंगा।"
    else
      "🌐 Language switched to *English*!"
    end
  end

  def handle_rewrite(user, args)
    return "Please provide a message to rewrite. Example:\n/rewrite You never listen to me!" if args.blank?

    conversation = active_conversation(user)
    language = conversation.language || "english"
    result = @gemini.rewrite_message(args, language: language)
    tone = result[:tone_analysis]

    <<~MSG
      ✏️ *Rewritten Message:*
      #{result[:rewritten]}

      📊 *Tone Analysis:*
      • Original tone: #{tone[:original_tone]}
      • Emotional intensity: #{tone[:emotional_intensity]}%
      • Defensiveness risk: #{tone[:defensiveness_risk]}%
      • Constructiveness: #{tone[:constructiveness]}%
      💡 #{tone[:suggested_approach]}
    MSG
  rescue StandardError => e
    Rails.logger.error("Rewrite error: #{e.message}")
    "Sorry, I couldn't rewrite that message right now. Please try again."
  end

  def handle_persona(user, args)
    valid_personas = %w[clinical_psychologist empathetic_listener relationship_coach communication_expert]

    if args.blank? || !valid_personas.include?(args.strip.downcase)
      return <<~MSG
        Please choose a persona:
        • /persona clinical_psychologist
        • /persona empathetic_listener
        • /persona relationship_coach
        • /persona communication_expert
      MSG
    end

    conversation = active_conversation(user)
    conversation.update!(persona: args.strip.downcase)

    # Reset system message
    conversation.messages.where(role: "system").destroy_all
    system_prompt = persona_system_prompt(conversation.persona)
    conversation.messages.create!(role: "system", content: system_prompt)

    "Persona changed to *#{args.strip.titleize}*! 🎭\nMy responses will now reflect this style."
  end

  def handle_reset(user, _args)
    # Archive old conversation and start fresh
    user.conversations.where(status: :active).update_all(status: :archived)
    "Conversation reset! 🔄\nSend me a message to start a new chat."
  end

  def handle_mediate(user, args)
    if args.blank?
      return <<~MSG
        ⚖️ *Conflict Mediator*

        Start a mediation session by providing the topic:
        /mediate Division of household chores

        Then add perspectives and/or screenshots:
        /myperspective I feel like I do most of the housework...
        /partnerperspective My partner says they handle finances...
        📸 Send chat screenshots as photos

        When ready, get analysis:
        /analyze
      MSG
    end

    # Create a new conflict session with placeholder perspective to pass validation
    session = user.conflict_sessions.create!(
      topic: args.strip,
      partner_name: "Partner",
      user_perspective: "(pending)",
      status: :pending_partner
    )

    <<~MSG
      ⚖️ *Mediation session started!*
      Topic: #{args.strip}

      Now add both perspectives:
      1️⃣ /myperspective Your side of the story...
      2️⃣ /partnerperspective Your partner's side...

      Then type /analyze to get AI mediation.
    MSG
  rescue StandardError => e
    Rails.logger.error("Mediate error: #{e.message}")
    "Sorry, I couldn't create the mediation session. Please try again."
  end

  def handle_my_perspective(user, args)
    return "Please provide your perspective:\n/myperspective I feel that..." if args.blank?

    session = user.conflict_sessions.order(created_at: :desc).first
    unless session
      return "No active mediation session. Start one with:\n/mediate <topic>"
    end

    session.update!(user_perspective: args.strip)

    if session.partner_perspective.present?
      "✅ Your perspective saved! Both perspectives are ready.\nType /analyze to get AI mediation."
    else
      "✅ Your perspective saved!\nNow add your partner's perspective:\n/partnerperspective Their side of the story..."
    end
  end

  def handle_partner_perspective(user, args)
    return "Please provide your partner's perspective:\n/partnerperspective They feel that..." if args.blank?

    session = user.conflict_sessions.order(created_at: :desc).first
    unless session
      return "No active mediation session. Start one with:\n/mediate <topic>"
    end

    session.update!(partner_perspective: args.strip)

    if session.user_perspective.present?
      "✅ Partner's perspective saved! Both perspectives are ready.\nType /analyze to get AI mediation."
    else
      "✅ Partner's perspective saved!\nNow add your perspective:\n/myperspective Your side of the story..."
    end
  end

  def handle_analyze(user, _args)
    session = user.conflict_sessions.order(created_at: :desc).first

    unless session
      return "No active mediation session. Start one with:\n/mediate <topic>"
    end

    has_perspectives = session.user_perspective.present? && session.partner_perspective.present?
    has_screenshots = session.chat_screenshots.attached?

    unless has_perspectives || has_screenshots
      return <<~MSG
        Need at least one of:
        • Both perspectives (/myperspective + /partnerperspective)
        • Chat screenshots (send photos)

        Then type /analyze again.
      MSG
    end

    # Collect screenshot data
    image_data = []
    if session.chat_screenshots.attached?
      session.chat_screenshots.each do |screenshot|
        image_data << {
          base64: Base64.strict_encode64(screenshot.download),
          mime_type: screenshot.content_type
        }
      end
    end

    conversation = active_conversation(user)
    language = conversation.language || "english"

    result = @gemini.mediate_conflict(
      topic: session.topic,
      user_name: user.first_name,
      partner_name: session.partner_name,
      user_perspective: session.user_perspective || "Not provided (see screenshots)",
      partner_perspective: session.partner_perspective || "Not provided (see screenshots)",
      language: language,
      images: image_data
    )

    session.update!(
      ai_analysis: result[:analysis],
      ai_summary: result[:summary],
      status: :completed
    )

    # Truncate if too long for messaging
    analysis_text = result[:analysis].length > 3000 ? result[:analysis][0..2997] + "..." : result[:analysis]

    <<~MSG
      ⚖️ *Mediation Analysis*
      Topic: #{session.topic}

      #{analysis_text}

      📋 *Summary:*
      #{result[:summary]}

      Start a new session anytime with /mediate <topic>
    MSG
  rescue StandardError => e
    Rails.logger.error("Analyze error: #{e.message}")
    "Sorry, I couldn't analyze right now. Please try again."
  end

  def handle_chat(user, text)
    conversation = active_conversation(user)

    # Save user message
    conversation.messages.create!(role: "user", content: text)

    # Build message history for AI
    chat_messages = conversation.messages.ordered.last(20).map do |msg|
      { role: msg.role, content: msg.content }
    end

    response = @gemini.chat(chat_messages, language: conversation.language || "english")

    # Save assistant response
    conversation.messages.create!(role: "assistant", content: response)

    response
  rescue StandardError => e
    Rails.logger.error("Chat error via #{@platform}: #{e.message}")
    "I'm sorry, I'm having trouble right now. Please try again in a moment."
  end

  def active_conversation(user)
    conversation = user.conversations.where(status: :active).order(updated_at: :desc).first

    unless conversation
      conversation = user.conversations.create!(
        title: "#{@platform.to_s.capitalize} Chat #{Time.current.strftime('%b %d')}",
        persona: :empathetic_listener,
        status: :active
      )
      system_prompt = persona_system_prompt(conversation.persona)
      conversation.messages.create!(role: "system", content: system_prompt)
    end

    conversation
  end

  def persona_system_prompt(persona)
    case persona
    when "clinical_psychologist"
      "You are a clinical psychologist specializing in couples therapy. You provide evidence-based insights, draw from attachment theory and the Gottman Method, and help couples understand the psychological patterns in their relationship. Be professional yet warm. Keep responses concise for messaging."
    when "empathetic_listener"
      "You are an empathetic listener and relationship companion. You focus on emotional validation, active listening, and creating a safe space for expression. You gently guide conversations toward understanding and healing. Keep responses concise for messaging."
    when "relationship_coach"
      "You are a proactive relationship coach. You focus on actionable strategies, goal-setting, and accountability. You help couples build positive habits and work toward concrete relationship improvements. Keep responses concise for messaging."
    when "communication_expert"
      "You are a communication expert specializing in couples dynamics. You analyze language patterns, teach nonviolent communication techniques, and help couples express needs effectively without triggering defensiveness. Keep responses concise for messaging."
    else
      "You are a helpful AI relationship assistant. You provide thoughtful, balanced advice to help couples strengthen their relationship. Keep responses concise for messaging."
    end
  end
end

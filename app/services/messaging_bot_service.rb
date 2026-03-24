class MessagingBotService
  COMMANDS = {
    "/start" => :handle_start,
    "/help" => :handle_help,
    "/link" => :handle_link,
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
    command, args = parse_command(text)

    # /start and /link work without a linked account
    if command == "/start"
      user = find_user(platform_user_id)
      return handle_start(user, args)
    end

    if command == "/link"
      return handle_link(platform_user_id, args, user_name)
    end

    # All other commands require a linked account
    user = find_user(platform_user_id)
    unless user
      return unlinked_message
    end

    result = if command && COMMANDS.key?(command)
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

    # Wrap with interactive UI for WhatsApp
    return result if @platform == :telegram
    whatsapp_enrich(result, command)
  end

  def process_photo(platform_user_id:, image_data:, caption: "", user_name: nil)
    user = find_user(platform_user_id)
    return unlinked_message unless user

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
    user = find_user(platform_user_id)
    return unlinked_message unless user

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

  def find_user(platform_user_id)
    field = platform_field
    User.find_by(field => platform_user_id.to_s)
  end

  def handle_link(platform_user_id, args, user_name = nil)
    code = args&.strip&.upcase

    if code.blank?
      return link_instructions_message
    end

    # Find user by link code
    user = User.find_by(bot_link_code: code)

    unless user
      return "❌ Invalid link code. Please check and try again.\n\nGet your code from the CoupleLens dashboard."
    end

    if user.bot_link_code_expires_at && user.bot_link_code_expires_at < Time.current
      return "❌ This link code has expired. Please generate a new one from your CoupleLens dashboard."
    end

    # Clear any old bot-created account that holds this platform ID
    field = platform_field
    old_user = User.where(field => platform_user_id.to_s).where.not(id: user.id).first
    if old_user && old_user.email&.end_with?("@couplelens.bot")
      old_user.destroy
    elsif old_user
      old_user.update!(field => nil)
    end

    # Link the platform account
    user.update!(
      field => platform_user_id.to_s,
      bot_link_code: nil,
      bot_link_code_expires_at: nil
    )

    "✅ Account linked successfully! Welcome, #{user.first_name}! 🎉\n\nYou now have full access to CoupleLens bot. Type /help to see all features."
  end

  def unlinked_message
    if @platform == :whatsapp
      {
        type: :buttons,
        header: "🔒 Account Required",
        body: "To use CoupleLens bot, you need a CoupleLens account.\n\n1️⃣ Sign up at the CoupleLens website\n2️⃣ Go to Dashboard → Link Bot\n3️⃣ Send the code here: /link YOUR-CODE",
        buttons: [
          { id: "/start", title: "ℹ️ More Info" }
        ]
      }
    else
      <<~MSG
        🔒 *Account Required*

        To use CoupleLens bot, you need a CoupleLens account.

        1️⃣ Sign up at the CoupleLens website
        2️⃣ Go to Dashboard → Link Bot
        3️⃣ Send the code here: /link YOUR-CODE

        Type /link YOUR-CODE to connect your account.
      MSG
    end
  end

  def link_instructions_message
    if @platform == :whatsapp
      {
        type: :buttons,
        header: "🔗 Link Your Account",
        body: "To link your CoupleLens account:\n\n1️⃣ Log in at the CoupleLens website\n2️⃣ Go to Dashboard → Link Bot\n3️⃣ Copy your link code\n4️⃣ Send: /link YOUR-CODE",
        buttons: [
          { id: "/start", title: "ℹ️ More Info" }
        ]
      }
    else
      <<~MSG
        🔗 *Link Your Account*

        To link your CoupleLens account:
        1️⃣ Log in at the CoupleLens website
        2️⃣ Go to Dashboard → Link Bot
        3️⃣ Copy your link code
        4️⃣ Send: /link YOUR-CODE
      MSG
    end
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
    unless user
      # Unlinked user — show welcome + link instructions
      if @platform == :whatsapp
        return {
          type: :buttons,
          header: "Welcome to CoupleLens! 💑",
          body: "I'm your AI relationship assistant.\n\nTo get started, you need a CoupleLens account.\n\n1️⃣ Sign up at the CoupleLens website\n2️⃣ Go to Dashboard → Link Bot\n3️⃣ Send your code: /link YOUR-CODE",
          buttons: [
            { id: "/link", title: "🔗 Link Account" }
          ]
        }
      else
        return <<~MSG
          Welcome to CoupleLens! 💑

          I'm your AI relationship assistant.

          To get started, you need a CoupleLens account:
          1️⃣ Sign up at the CoupleLens website
          2️⃣ Go to Dashboard → Link Bot
          3️⃣ Send your code: /link YOUR-CODE
        MSG
      end
    end

    # Linked user — show full menu
    if @platform == :whatsapp
      {
        type: :list,
        header: "CoupleLens 💑",
        body: "Welcome! I'm your AI relationship assistant. Choose what you'd like to do:",
        footer: "Or just type a message to chat with me",
        button_text: "📋 Menu",
        sections: [
          {
            title: "💬 Communication",
            rows: [
              { id: "/help", title: "❓ Help", description: "See all available features" },
              { id: "/rewrite", title: "✏️ Rewrite Message", description: "Rewrite a heated message calmly" },
              { id: "/reset", title: "🔄 Reset Chat", description: "Start a fresh conversation" }
            ]
          },
          {
            title: "⚖️ Conflict Resolution",
            rows: [
              { id: "/mediate", title: "⚖️ Start Mediation", description: "Begin a conflict mediation session" },
              { id: "/analyze", title: "📊 Analyze", description: "Get AI mediation analysis" }
            ]
          },
          {
            title: "⚙️ Settings",
            rows: [
              { id: "/language", title: "🌐 Language", description: "Switch between English & Hindi" },
              { id: "/persona", title: "🎭 Change Persona", description: "Change AI personality style" }
            ]
          }
        ]
      }
    else
      <<~MSG
        Welcome to CoupleLens! 💑

        I'm your AI relationship assistant. Here's what I can do:

        💬 *Chat* — Just send me a message and I'll help with relationship advice
        ✏️ */rewrite <message>* — Rewrite a heated message to be calmer
        ⚖️ */mediate <topic>* — Start a conflict mediation session
        🌐 */language <en|hi>* — Switch language (English/Hindi)
        🎭 */persona <type>* — Change my personality:
           • clinical_psychologist
           • empathetic_listener
           • relationship_coach
           • communication_expert
        🔄 */reset* — Start a fresh conversation
        ❓ */help* — Show this menu again

        Let's start! What's on your mind?
      MSG
    end
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

      if @platform == :whatsapp
        return {
          type: :buttons,
          header: "🌐 Language",
          body: "Current language: #{current.capitalize}\n\nChoose your preferred language:",
          buttons: [
            { id: "/language en", title: "🇬🇧 English" },
            { id: "/language hi", title: "🇮🇳 Hindi" }
          ]
        }
      end

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
      if @platform == :whatsapp
        return {
          type: :list,
          header: "🎭 Choose Persona",
          body: "Select an AI personality style for your conversations:",
          button_text: "🎭 Personas",
          sections: [
            {
              title: "Available Personas",
              rows: [
                { id: "/persona clinical_psychologist", title: "🧠 Clinical Psychologist", description: "Evidence-based insights & therapy" },
                { id: "/persona empathetic_listener", title: "💛 Empathetic Listener", description: "Emotional validation & safe space" },
                { id: "/persona relationship_coach", title: "💪 Relationship Coach", description: "Actionable strategies & goals" },
                { id: "/persona communication_expert", title: "🗣️ Communication Expert", description: "Better expression & understanding" }
              ]
            }
          ]
        }
      end

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

  # Add contextual quick-reply buttons for WhatsApp responses
  def whatsapp_enrich(result, command)
    # If already an interactive response, return as-is
    return result if result.is_a?(Hash) && result[:type]

    text = result.to_s

    case command
    when "/start", "/help"
      result # Already handled with interactive menu
    when "/reset"
      {
        type: :buttons,
        body: text,
        buttons: [
          { id: "/help", title: "📋 Menu" },
          { id: "/mediate", title: "⚖️ Mediate" }
        ]
      }
    when "/rewrite"
      if text.include?("Please provide")
        text # Needs user input, no buttons
      else
        {
          type: :buttons,
          body: text,
          buttons: [
            { id: "/help", title: "📋 Menu" },
            { id: "/reset", title: "🔄 Reset" }
          ]
        }
      end
    when "/mediate"
      if text.include?("Please provide") || text.include?("Start one with")
        text
      else
        {
          type: :buttons,
          body: text,
          footer: "Type: /myperspective Your side of the story...",
          buttons: [
            { id: "/help", title: "📋 Menu" }
          ]
        }
      end
    when "/myperspective"
      if text.include?("Both perspectives are ready")
        {
          type: :buttons,
          body: text,
          buttons: [
            { id: "/analyze", title: "📊 Analyze Now" }
          ]
        }
      else
        text
      end
    when "/partnerperspective"
      if text.include?("Both perspectives are ready")
        {
          type: :buttons,
          body: text,
          buttons: [
            { id: "/analyze", title: "📊 Analyze Now" }
          ]
        }
      else
        text
      end
    when "/analyze"
      {
        type: :buttons,
        body: text,
        buttons: [
          { id: "/mediate", title: "⚖️ New Mediation" },
          { id: "/help", title: "📋 Menu" }
        ]
      }
    when "/language"
      if text.is_a?(String) && (text.include?("switched") || text.include?("बदल दी"))
        {
          type: :buttons,
          body: text,
          buttons: [
            { id: "/help", title: "📋 Menu" }
          ]
        }
      else
        text
      end
    when "/persona"
      if text.is_a?(String) && text.include?("changed to")
        {
          type: :buttons,
          body: text,
          buttons: [
            { id: "/help", title: "📋 Menu" },
            { id: "/reset", title: "🔄 Reset Chat" }
          ]
        }
      else
        text
      end
    else
      # Regular chat - add a subtle menu button
      {
        type: :buttons,
        body: text,
        buttons: [
          { id: "/help", title: "📋 Menu" },
          { id: "/rewrite", title: "✏️ Rewrite" },
          { id: "/mediate", title: "⚖️ Mediate" }
        ]
      }
    end
  end
end

class MessagingBotService
  COMMANDS = {
    "/start" => :handle_start,
    "/help" => :handle_help,
    "/link" => :handle_link,
    "/agent" => :handle_agent,
    "/rewrite" => :handle_rewrite,
    "/mediate" => :handle_mediate,
    "/myperspective" => :handle_my_perspective,
    "/partnerperspective" => :handle_partner_perspective,
    "/analyze" => :handle_analyze,
    "/language" => :handle_language,
    "/reset" => :handle_reset
  }.freeze

  AGENTS = {
    "clinical_psychologist" => {
      name: "🧠 Clinical Psychologist",
      short: "🧠 Psychologist",
      description: "Evidence-based therapy & attachment insights",
      prompt: "You are a clinical psychologist specializing in couples therapy. You provide evidence-based insights, draw from attachment theory and the Gottman Method, and help couples understand the psychological patterns in their relationship. Be professional yet warm. Keep responses concise for messaging."
    },
    "empathetic_listener" => {
      name: "💛 Empathetic Listener",
      short: "💛 Listener",
      description: "Emotional validation & safe space",
      prompt: "You are an empathetic listener and relationship companion. You focus on emotional validation, active listening, and creating a safe space for expression. You gently guide conversations toward understanding and healing. Keep responses concise for messaging."
    },
    "relationship_coach" => {
      name: "💪 Relationship Coach",
      short: "💪 Coach",
      description: "Action plans, goals & accountability",
      prompt: "You are a proactive relationship coach. You focus on actionable strategies, goal-setting, and accountability. You help couples build positive habits and work toward concrete relationship improvements. Keep responses concise for messaging."
    },
    "communication_expert" => {
      name: "🗣️ Communication Expert",
      short: "🗣️ Expert",
      description: "NVC techniques & better expression",
      prompt: "You are a communication expert specializing in couples dynamics. You analyze language patterns, teach nonviolent communication techniques, and help couples express needs effectively without triggering defensiveness. Keep responses concise for messaging."
    }
  }.freeze

  def initialize(platform:)
    @platform = platform # :telegram or :whatsapp
    @gemini = GeminiService.new
  end

  def process_message(platform_user_id:, text:, user_name: nil)
    # Handle WhatsApp button reply IDs for link confirmation
    if text&.start_with?("confirm_link_")
      user_id = text.sub("confirm_link_", "")
      return handle_confirm_link(platform_user_id, user_id)
    end

    if text == "reject_link"
      if @platform == :telegram
        return telegram_reply(
          "❌ *Link Cancelled*\n\nNo changes were made to your account.\n\nYou can try linking again anytime by typing `/link CODE` with a valid link code from your dashboard.",
          [[{ text: "ℹ️ Get Link Code Instructions", callback_data: "/link" }]]
        )
      end
      return "❌ Link cancelled. No changes were made.\n\nYou can try again anytime by typing `/link CODE` with a valid link code from your dashboard."
    end

    command, args = parse_command(text)

    # /start and /link work without a linked account
    if command == "/start"
      # Handle Telegram deep link: /start LINK_15
      if args&.start_with?("LINK_")
        user_id = args.sub("LINK_", "")
        return handle_confirm_link(platform_user_id, user_id)
      end
      user = find_user(platform_user_id)
      return handle_start(user, platform_user_id)
    end

    if command == "/link"
      return handle_link(platform_user_id, args, user_name)
    end

    if command == "/confirm_link"
      return handle_confirm_link(platform_user_id, args)
    end

    if command == "/reject_link"
      if @platform == :telegram
        return telegram_reply(
          "❌ *Link Cancelled*\n\nNo changes were made to your account.\n\nYou can try linking again anytime by typing `/link CODE` with a valid link code from your dashboard.",
          [[{ text: "ℹ️ Get Link Code Instructions", callback_data: "/link" }]]
        )
      end
      return "❌ Link cancelled. No changes were made.\n\nYou can try again anytime by typing `/link CODE` with a valid link code from your dashboard."
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
    elsif text.start_with?("/")
      handle_unknown_command(user, text)
    else
      handle_chat(user, text)
    end

    # Wrap with interactive UI
    return telegram_enrich(result, command) if @platform == :telegram
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
      if @platform == :telegram
        return telegram_reply(
          "❌ *Invalid link code*\n\nPlease check and try again.\nGet your code from the CoupleLens dashboard.",
          [[{ text: "🔄 Try Again", callback_data: "/link" }]]
        )
      end
      return "❌ Invalid link code. Please check and try again.\n\nGet your code from the CoupleLens dashboard."
    end

    if user.bot_link_code_expires_at && user.bot_link_code_expires_at < Time.current
      if @platform == :telegram
        return telegram_reply(
          "⏰ *Code Expired*\n\nThis link code has expired. Please generate a new one from your CoupleLens dashboard.",
          [[{ text: "🔄 Try Again", callback_data: "/link" }]]
        )
      end
      return "❌ This link code has expired. Please generate a new one from your CoupleLens dashboard."
    end

    # Send confirmation message instead of directly linking
    if @platform == :telegram
      return telegram_reply(
        "🔗 *Link Account Confirmation*\n\n" \
        "You're about to link this Telegram account to:\n" \
        "👤 *#{user.first_name} #{user.last_name}*\n" \
        "📧 #{user.email}\n\n" \
        "Once linked, you'll have full access to CoupleLens features via this chat.\n\n" \
        "Do you want to proceed?",
        [
          [{ text: "✅ Yes, Link Account", callback_data: "confirm_link_#{user.id}" }],
          [{ text: "❌ Cancel", callback_data: "reject_link" }]
        ]
      )
    else
      # WhatsApp
      {
        type: :buttons,
        header: "🔗 Link Account",
        body: "You're about to link this WhatsApp to:\n\n" \
              "👤 *#{user.first_name} #{user.last_name}*\n" \
              "📧 #{user.email}\n\n" \
              "Once linked, you'll have full access to CoupleLens features.\n\n" \
              "Do you want to proceed?",
        buttons: [
          { id: "confirm_link_#{user.id}", title: "✅ Yes, Link" },
          { id: "reject_link", title: "❌ Cancel" }
        ]
      }
    end
  end

  def handle_confirm_link(platform_user_id, args)
    user_id = args&.strip
    user = User.find_by(id: user_id)

    unless user
      return "❌ Link request not found or expired."
    end

    # Verify link code exists and is not expired
    # Support both invitation codes (WA-LINK-, TG-LINK-) and regular link codes
    unless user.bot_link_code.present? && user.bot_link_code_expires_at && user.bot_link_code_expires_at > Time.current
      return "❌ This link request has expired. Please generate a new code from the CoupleLens dashboard."
    end

    field = platform_field

    # Clear any old account holding this platform ID
    old_user = User.where(field => platform_user_id.to_s).where.not(id: user.id).first
    if old_user && old_user.email&.end_with?("@couplelens.bot")
      old_user.destroy
    elsif old_user
      old_user.update!(field => nil)
    end

    # Link the account
    user.update!(
      field => platform_user_id.to_s,
      bot_link_code: nil,
      bot_link_code_expires_at: nil
    )

    # Archive any pre-existing conversations for this platform so the user starts fresh
    user.conversations.where(platform: @platform.to_s, status: :active).update_all(status: :archived)

    if @platform == :telegram
      return telegram_reply(
        "✅ *Account linked successfully!*\n\nWelcome, #{user.first_name}! 🎉\nYour CoupleLens account is now connected.",
        [
          [{ text: "📋 Show Menu", callback_data: "/help" }],
          [{ text: "🤖 Pick Agent", callback_data: "/agent" }]
        ]
      )
    end

    {
      type: :list,
      header: "✅ Account Linked!",
      body: "Welcome, #{user.first_name}! 🎉\n\nYour CoupleLens account is now connected.\n\nChoose what you'd like to do:",
      button_text: "📋 Menu",
      sections: [
        {
          title: "🤖 AI Agents",
          rows: AGENTS.map { |key, agent|
            { id: "/agent #{key}", title: agent[:name], description: agent[:description] }
          }
        },
        {
          title: "✏️ Communication Tools",
          rows: [
            { id: "/rewrite", title: "✏️ Rewrite Message", description: "Rewrite a heated message calmly" }
          ]
        },
        {
          title: "⚖️ Conflict Resolution",
          rows: [
            { id: "/mediate", title: "⚖️ Start Mediation", description: "Begin a conflict mediation session" }
          ]
        },
        {
          title: "⚙️ Settings",
          rows: [
            { id: "/language", title: "🌐 Language", description: "Switch between English & Hindi" }
          ]
        }
      ]
    }
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
      telegram_reply(
        "🔒 *Account Required*\n\nTo use CoupleLens bot, you need a CoupleLens account.\n\n1️⃣ Sign up at the CoupleLens website\n2️⃣ Go to Dashboard → *Link Bot*\n3️⃣ Copy your code and send it here",
        [[{ text: "🔗 I Have a Code", callback_data: "/link" }]]
      )
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
      telegram_reply(
        "🔗 *Link Your Account*\n\n1️⃣ Log in at the CoupleLens website\n2️⃣ Go to Dashboard → *Link Bot*\n3️⃣ Copy your link code\n4️⃣ Send here: `/link YOUR-CODE`",
        [[{ text: "ℹ️ More Info", callback_data: "/start" }]]
      )
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

  def handle_start(user, platform_user_id = nil)
    unless user
      # Unlinked user — show welcome + link instructions
      if @platform == :whatsapp
        return {
          type: :buttons,
          header: "Welcome to CoupleLens! 💑",
          body: "I'm your AI relationship assistant.\n\nTo get started, you need a CoupleLens account.\n\n1️⃣ Sign up at the CoupleLens website\n2️⃣ Go to Dashboard → Link Bot\n3️⃣ Enter your phone number and click Send Link",
          buttons: [
            { id: "/link", title: "🔗 Link Account" }
          ]
        }
      else
        chat_id_text = platform_user_id ? "\n\n📋 *Your Chat ID:* `#{platform_user_id}`\n_(Copy this to the CoupleLens dashboard)_" : ""
        return telegram_reply(
          "💑 *Welcome to CoupleLens!*\n\nI'm your AI relationship assistant.\n\nTo link your account:\n\n1️⃣ Sign up at the CoupleLens website\n2️⃣ Go to Dashboard → *Link Bot*\n3️⃣ Paste your Chat ID and click Send Link#{chat_id_text}",
          [[{ text: "🔗 I Have a Link Code", callback_data: "/link" }]]
        )
      end
    end

    # Linked user — show full menu
    if @platform == :whatsapp
      {
        type: :list,
        header: "CoupleLens 💑",
        body: "Welcome back, #{user.first_name}! 👋\n\nI'm your AI relationship assistant. Choose what you'd like to do:",
        footer: "Use the menu to explore features",
        button_text: "📋 Menu",
        sections: [
          {
            title: "🤖 AI Agents",
            rows: [
              { id: "/agent", title: "🤖 Chat with Agent", description: "Pick an AI agent and start chatting" },
              { id: "/reset", title: "🔄 Reset Chat", description: "Clear history and start fresh" }
            ]
          },
          {
            title: "✏️ Communication Tools",
            rows: [
              { id: "/rewrite", title: "✏️ Rewrite Message", description: "Rewrite a heated message calmly" }
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
              { id: "/language", title: "🌐 Language", description: "Switch between English & Hindi" }
            ]
          }
        ]
      }
    else
      current_agent = active_conversation(user).persona
      agent_label = AGENTS[current_agent] ? AGENTS[current_agent][:short] : "None"

      telegram_reply(
        "💑 *Welcome back, #{user.first_name}!*\n\nCurrent agent: *#{agent_label}*\n\n━━━━━━━━━━━━━━━━\n🤖 *Agent* — Chat with an AI specialist\n✏️ *Rewrite* — Calm down a heated message\n⚖️ *Mediate* — AI conflict resolution\n🌐 *Language* — English / Hindi\n🔄 *Reset* — Clear chat & switch agent\n━━━━━━━━━━━━━━━━\n\nTap a button below to get started! 👇",
        [
          [
            { text: "🤖 Pick Agent", callback_data: "/agent" },
            { text: "✏️ Rewrite", callback_data: "/rewrite" }
          ],
          [
            { text: "⚖️ Mediate", callback_data: "/mediate" },
            { text: "📊 Analyze", callback_data: "/analyze" }
          ],
          [
            { text: "🌐 Language", callback_data: "/language" },
            { text: "🔄 Reset Chat", callback_data: "/reset" }
          ]
        ]
      )
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

      return telegram_reply(
        "🌐 *Language Settings*\n\nCurrent: *#{current.capitalize}*\n\nChoose your preferred language:",
        [[
          { text: "🇬🇧 English", callback_data: "/language en" },
          { text: "🇮🇳 Hindi", callback_data: "/language hi" }
        ]]
      )
    end

    language = valid[lang_key]
    conversation = active_conversation(user)
    conversation.update!(language: language)

    if language == "hindi"
      if @platform == :telegram
        return telegram_reply(
          "🌐 भाषा हिंदी में बदल दी गई है!\n\nअब मैं हिंदी में जवाब दूंगा। 🇮🇳",
          [[
            { text: "📋 मेनू", callback_data: "/help" },
            { text: "🇬🇧 Switch to English", callback_data: "/language en" }
          ]]
        )
      end
      "🌐 भाषा हिंदी में बदल दी गई है! अब मैं हिंदी में जवाब दूंगा।"
    else
      if @platform == :telegram
        return telegram_reply(
          "🌐 Language switched to *English*! 🇬🇧",
          [[
            { text: "📋 Menu", callback_data: "/help" },
            { text: "🇮🇳 Switch to Hindi", callback_data: "/language hi" }
          ]]
        )
      end
      "🌐 Language switched to *English*!"
    end
  end

  def handle_rewrite(user, args)
    if args.blank?
      if @platform == :telegram
        return telegram_reply(
          "✏️ *Rewrite a Message*\n\nSend me a heated message and I'll rewrite it to be calmer and more constructive.\n\n*Example:*\n`/rewrite You never listen to me and I'm sick of it`",
          [[
            { text: "📋 Menu", callback_data: "/help" },
            { text: "⚖️ Mediate Instead", callback_data: "/mediate" }
          ]]
        )
      end
      return "Please provide a message to rewrite. Example:\n/rewrite You never listen to me!"
    end

    conversation = active_conversation(user)
    language = conversation.language || "english"
    result = @gemini.rewrite_message(args, language: language)
    tone = result[:tone_analysis]

    text = <<~MSG.strip
      ✏️ *Rewritten Message:*
      #{result[:rewritten]}

      ━━━━━━━━━━━━━━━━
      📊 *Tone Analysis:*
      • Original tone: #{tone[:original_tone]}
      • Emotional intensity: #{tone[:emotional_intensity]}%
      • Defensiveness risk: #{tone[:defensiveness_risk]}%
      • Constructiveness: #{tone[:constructiveness]}%
      💡 #{tone[:suggested_approach]}
    MSG

    if @platform == :telegram
      return telegram_reply(text, [
        [
          { text: "✏️ Rewrite Another", callback_data: "/rewrite" },
          { text: "📋 Menu", callback_data: "/help" }
        ]
      ])
    end

    text
  rescue StandardError => e
    Rails.logger.error("Rewrite error: #{e.message}")
    "Sorry, I couldn't rewrite that message right now. Please try again."
  end

  def handle_mediate(user, args)
    if args.blank?
      if @platform == :telegram
        return telegram_reply(
          "⚖️ *Conflict Mediator*\n\nI'll help mediate a conflict between you and your partner.\n\n*How to use:*\nSend `/mediate` followed by the topic.\n\n*Example:*\n`/mediate Division of household chores`",
          [[{ text: "📋 Menu", callback_data: "/help" }]]
        )
      end

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

    if @platform == :telegram
      return telegram_reply(
        "⚖️ *Mediation session started!*\n\n📌 Topic: _#{args.strip}_\n\n━━━━━━━━━━━━━━━━\n*Next:* Add both perspectives, then analyze.\n\nYou can also send 📸 chat screenshots!",
        [
          [{ text: "📝 Add My Perspective", callback_data: "/myperspective" }],
          [{ text: "👥 Add Partner's Perspective", callback_data: "/partnerperspective" }],
          [{ text: "📊 Analyze Now", callback_data: "/analyze" }]
        ]
      )
    end

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
    if args.blank?
      if @platform == :telegram
        return telegram_reply(
          "📝 *Your Perspective*\n\nSend `/myperspective` followed by your side of the story.\n\n*Example:*\n`/myperspective I feel like I do most of the housework and it's exhausting...`",
          [[{ text: "⬅️ Back to Menu", callback_data: "/help" }]]
        )
      end
      return "Please provide your perspective:\n/myperspective I feel that..."
    end

    session = user.conflict_sessions.order(created_at: :desc).first
    unless session
      if @platform == :telegram
        return telegram_reply(
          "❌ No active mediation session.\n\nStart one first:",
          [[{ text: "⚖️ Start Mediation", callback_data: "/mediate" }]]
        )
      end
      return "No active mediation session. Start one with:\n/mediate <topic>"
    end

    session.update!(user_perspective: args.strip)

    if session.partner_perspective.present?
      if @platform == :telegram
        return telegram_reply(
          "✅ *Your perspective saved!*\n\n🎉 Both perspectives are ready!\nTap below to get AI mediation analysis.",
          [[{ text: "📊 Analyze Now", callback_data: "/analyze" }]]
        )
      end
      "✅ Your perspective saved! Both perspectives are ready.\nType /analyze to get AI mediation."
    else
      if @platform == :telegram
        return telegram_reply(
          "✅ *Your perspective saved!*\n\nNow add your partner's perspective:",
          [
            [{ text: "👥 Add Partner's Perspective", callback_data: "/partnerperspective" }],
            [{ text: "📊 Analyze Anyway", callback_data: "/analyze" }]
          ]
        )
      end
      "✅ Your perspective saved!\nNow add your partner's perspective:\n/partnerperspective Their side of the story..."
    end
  end

  def handle_partner_perspective(user, args)
    if args.blank?
      if @platform == :telegram
        return telegram_reply(
          "👥 *Partner's Perspective*\n\nSend `/partnerperspective` followed by your partner's side.\n\n*Example:*\n`/partnerperspective They feel that I don't appreciate their efforts...`",
          [[{ text: "⬅️ Back to Menu", callback_data: "/help" }]]
        )
      end
      return "Please provide your partner's perspective:\n/partnerperspective They feel that..."
    end

    session = user.conflict_sessions.order(created_at: :desc).first
    unless session
      if @platform == :telegram
        return telegram_reply(
          "❌ No active mediation session.\n\nStart one first:",
          [[{ text: "⚖️ Start Mediation", callback_data: "/mediate" }]]
        )
      end
      return "No active mediation session. Start one with:\n/mediate <topic>"
    end

    session.update!(partner_perspective: args.strip)

    if session.user_perspective.present? && session.user_perspective != "(pending)"
      if @platform == :telegram
        return telegram_reply(
          "✅ *Partner's perspective saved!*\n\n🎉 Both perspectives are ready!\nTap below to get AI mediation analysis.",
          [[{ text: "📊 Analyze Now", callback_data: "/analyze" }]]
        )
      end
      "✅ Partner's perspective saved! Both perspectives are ready.\nType /analyze to get AI mediation."
    else
      if @platform == :telegram
        return telegram_reply(
          "✅ *Partner's perspective saved!*\n\nNow add your perspective:",
          [
            [{ text: "📝 Add My Perspective", callback_data: "/myperspective" }],
            [{ text: "📊 Analyze Anyway", callback_data: "/analyze" }]
          ]
        )
      end
      "✅ Partner's perspective saved!\nNow add your perspective:\n/myperspective Your side of the story..."
    end
  end

  def handle_analyze(user, _args)
    session = user.conflict_sessions.order(created_at: :desc).first

    unless session
      if @platform == :telegram
        return telegram_reply(
          "❌ No active mediation session.\n\nStart one first to use analysis:",
          [[{ text: "⚖️ Start Mediation", callback_data: "/mediate" }]]
        )
      end
      return "No active mediation session. Start one with:\n/mediate <topic>"
    end

    has_perspectives = session.user_perspective.present? && session.user_perspective != "(pending)" && session.partner_perspective.present?
    has_screenshots = session.chat_screenshots.attached?

    unless has_perspectives || has_screenshots
      if @platform == :telegram
        return telegram_reply(
          "⚠️ *Need more information*\n\nPlease add at least one of:\n• Both perspectives\n• Chat screenshots (send as photos)",
          [
            [{ text: "📝 My Perspective", callback_data: "/myperspective" }],
            [{ text: "👥 Partner's Perspective", callback_data: "/partnerperspective" }]
          ]
        )
      end

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

    text = <<~MSG.strip
      ⚖️ *Mediation Analysis*
      📌 Topic: _#{session.topic}_

      ━━━━━━━━━━━━━━━━
      #{analysis_text}

      ━━━━━━━━━━━━━━━━
      📋 *Summary:*
      #{result[:summary]}
    MSG

    if @platform == :telegram
      return telegram_reply(text, [
        [
          { text: "⚖️ New Mediation", callback_data: "/mediate" },
          { text: "📋 Menu", callback_data: "/help" }
        ]
      ])
    end

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

  def handle_agent(user, args)
    if args.present? && AGENTS.key?(args.strip.downcase)
      agent_key = args.strip.downcase
      conversation = active_conversation(user)
      conversation.update!(persona: agent_key)

      # Reset system message for the new agent
      conversation.messages.where(role: "system").destroy_all
      conversation.messages.create!(role: "system", content: AGENTS[agent_key][:prompt])

      agent = AGENTS[agent_key]

      if @platform == :telegram
        return telegram_reply(
          "#{agent[:name]} *activated!*\n\nYou're now chatting with the #{agent[:name]} agent.\nJust type a message to start! 💬",
          [
            [{ text: "📋 Menu", callback_data: "/help" }],
            [{ text: "🔄 Switch Agent", callback_data: "/agent" }]
          ]
        )
      end

      {
        type: :buttons,
        body: "#{agent[:name]} activated!\n\nYou're now chatting with the #{agent[:name]} agent.\nJust type a message to start! 💬",
        buttons: [
          { id: "/help", title: "📋 Menu" },
          { id: "/agent", title: "🔄 Switch Agent" }
        ]
      }
    else
      # Show agent selection
      agent_selection_message
    end
  end

  def handle_chat(user, text)
    conversation = active_conversation(user)

    # Check if an agent is selected
    unless conversation.persona.present? && AGENTS.key?(conversation.persona)
      return agent_required_message
    end

    # Save user message
    conversation.messages.create!(role: "user", content: text)

    # Ensure system message exists for current agent
    unless conversation.messages.where(role: "system").exists?
      conversation.messages.create!(role: "system", content: AGENTS[conversation.persona][:prompt])
    end

    # Build message history for AI
    chat_messages = conversation.messages.ordered.last(20).map do |msg|
      { role: msg.role, content: msg.content }
    end

    response = @gemini.chat(chat_messages, language: conversation.language || "english")

    # Save assistant response
    conversation.messages.create!(role: "assistant", content: response)

    response
  rescue Faraday::TooManyRequestsError => e
    Rails.logger.warn("Gemini 429 rate limit in chat via #{@platform}, retrying...")
    sleep(2)
    retry_response = @gemini.chat(chat_messages, language: conversation.language || "english")
    conversation.messages.create!(role: "assistant", content: retry_response)
    retry_response
  rescue StandardError => e
    Rails.logger.error("Chat error via #{@platform}: #{e.message}")
    "I'm sorry, I'm having trouble right now. Please try again in a moment."
  end

  def handle_reset(user, _args)
    user.conversations.where(status: :active).update_all(status: :archived)

    if @platform == :telegram
      return telegram_reply(
        "🔄 *Conversation reset!*\n\nYour chat history has been cleared.\nPick an agent to start a new conversation:",
        [
          [{ text: "🧠 Psychologist", callback_data: "/agent clinical_psychologist" }],
          [{ text: "💛 Listener", callback_data: "/agent empathetic_listener" }],
          [{ text: "💪 Coach", callback_data: "/agent relationship_coach" }],
          [{ text: "🗣️ Expert", callback_data: "/agent communication_expert" }]
        ]
      )
    end

    {
      type: :list,
      header: "🔄 Conversation Reset",
      body: "Your chat history has been cleared.\nPick an agent to start fresh:",
      button_text: "🤖 Choose Agent",
      sections: [
        {
          title: "AI Agents",
          rows: AGENTS.map { |key, agent|
            { id: "/agent #{key}", title: agent[:name], description: agent[:description] }
          }
        }
      ]
    }
  end

  def handle_unknown_command(user, text)
    command = text.split(" ", 2).first.downcase

    # Find closest matching command
    suggestions = COMMANDS.keys.select { |cmd| cmd.start_with?(command[0..2]) }

    if suggestions.any?
      if @platform == :telegram
        buttons = suggestions.first(3).map do |cmd|
          [{ text: cmd, callback_data: cmd }]
        end
        return telegram_reply(
          "🤔 Unknown command: `#{command}`\n\nDid you mean one of these?",
          buttons
        )
      end
      "🤔 Unknown command: #{command}\n\nDid you mean: #{suggestions.join(', ')}?"
    else
      if @platform == :telegram
        return telegram_reply(
          "🤔 Unknown command: `#{command}`\n\nHere are the available commands:",
          [
            [
              { text: "✏️ Rewrite", callback_data: "/rewrite" },
              { text: "⚖️ Mediate", callback_data: "/mediate" }
            ],
            [
              { text: "📋 Full Menu", callback_data: "/help" }
            ]
          ]
        )
      end
      "🤔 Unknown command. Type /help to see available commands."
    end
  end

  def active_conversation(user)
    conversation = user.conversations.where(status: :active, platform: @platform.to_s)
                                     .order(updated_at: :desc).first

    unless conversation
      conversation = user.conversations.create!(
        title: "#{@platform.to_s.capitalize} Bot #{Time.current.strftime('%b %d')}",
        status: :active,
        platform: @platform.to_s
      )
    end

    conversation
  end

  def agent_selection_message
    if @platform == :telegram
      telegram_reply(
        "🤖 *Choose Your AI Agent*\n\nEach agent has a unique personality and expertise.\nPick one to start chatting:\n\n🧠 *Clinical Psychologist* — Evidence-based therapy\n💛 *Empathetic Listener* — Emotional validation\n💪 *Relationship Coach* — Action plans & goals\n🗣️ *Communication Expert* — Better expression",
        [
          [{ text: "🧠 Psychologist", callback_data: "/agent clinical_psychologist" }],
          [{ text: "💛 Listener", callback_data: "/agent empathetic_listener" }],
          [{ text: "💪 Coach", callback_data: "/agent relationship_coach" }],
          [{ text: "🗣️ Expert", callback_data: "/agent communication_expert" }]
        ]
      )
    else
      {
        type: :list,
        header: "🤖 Choose Your AI Agent",
        body: "Each agent has a unique personality and expertise.\nPick one to start chatting:",
        button_text: "🤖 Choose Agent",
        sections: [
          {
            title: "AI Agents",
            rows: AGENTS.map { |key, agent|
              { id: "/agent #{key}", title: agent[:name], description: agent[:description] }
            }
          }
        ]
      }
    end
  end

  def agent_required_message
    if @platform == :telegram
      telegram_reply(
        "🤖 *Please pick an AI agent first!*\n\nYou need to select an agent before chatting.\nEach agent has a different style:",
        [
          [{ text: "🧠 Psychologist", callback_data: "/agent clinical_psychologist" }],
          [{ text: "💛 Listener", callback_data: "/agent empathetic_listener" }],
          [{ text: "💪 Coach", callback_data: "/agent relationship_coach" }],
          [{ text: "🗣️ Expert", callback_data: "/agent communication_expert" }]
        ]
      )
    else
      {
        type: :list,
        header: "🤖 Pick an Agent to Start",
        body: "You need to select an AI agent before chatting.\n\nChoose an agent or explore other features:",
        button_text: "📋 Menu",
        sections: [
          {
            title: "🤖 AI Agents",
            rows: AGENTS.map { |key, agent|
              { id: "/agent #{key}", title: agent[:name], description: agent[:description] }
            }
          },
          {
            title: "✏️ Communication Tools",
            rows: [
              { id: "/rewrite", title: "✏️ Rewrite Message", description: "Rewrite a heated message calmly" }
            ]
          },
          {
            title: "⚖️ Conflict Resolution",
            rows: [
              { id: "/mediate", title: "⚖️ Start Mediation", description: "Begin a conflict mediation session" }
            ]
          },
          {
            title: "⚙️ Settings",
            rows: [
              { id: "/language", title: "🌐 Language", description: "Switch between English & Hindi" }
            ]
          }
        ]
      }
    end
  end

  # Helper to build a Telegram response with inline keyboard
  def telegram_reply(text, inline_keyboard = nil)
    result = { text: text }
    if inline_keyboard
      result[:reply_markup] = { inline_keyboard: inline_keyboard }
    end
    result
  end

  # Add inline keyboard buttons to Telegram responses that don't already have them
  def telegram_enrich(result, command)
    # If already a structured response with keyboard, return as-is
    return result if result.is_a?(Hash) && result[:reply_markup]

    text = result.is_a?(Hash) ? result[:text].to_s : result.to_s

    case command
    when "/start", "/help", "/link", "/agent", "/reset", "/language",
         "/rewrite", "/mediate", "/myperspective", "/partnerperspective", "/analyze"
      # These are already handled with inline keyboards in their handlers
      result
    else
      # Regular chat — add agent switch + menu buttons
      telegram_reply(text, [
        [
          { text: "🤖 Switch Agent", callback_data: "/agent" },
          { text: "📋 Menu", callback_data: "/help" }
        ]
      ])
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
    when "/rewrite"
      if text.include?("Please provide")
        text # Needs user input, no buttons
      else
        {
          type: :buttons,
          body: text,
          buttons: [
            { id: "/help", title: "📋 Menu" },
            { id: "/rewrite", title: "✏️ Rewrite Again" }
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
    else
      # Regular chat — add agent switch + menu buttons
      {
        type: :buttons,
        body: text,
        buttons: [
          { id: "/agent", title: "🤖 Switch Agent" },
          { id: "/help", title: "📋 Menu" }
        ]
      }
    end
  end
end

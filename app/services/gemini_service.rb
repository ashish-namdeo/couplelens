class GeminiService
  MODEL = "gemini-2.5-flash"
  MAX_RETRIES = 3

  def initialize
    @client = OpenAI::Client.new
  end

  # AI Chat Assistant — sends full conversation history
  def chat(messages, language: "english")
    if language == "hindi"
      # Inject language instruction into the system message
      messages = messages.map do |m|
        if m[:role] == "system"
          { role: "system", content: m[:content] + "\n\nIMPORTANT: You MUST respond in Hindi (Devanagari script). The user will communicate in Hindi." }
        else
          m
        end
      end
    end

    response = chat_with_retry(
      messages: messages,
      temperature: 0.7,
      max_tokens: 1024
    )
    extract_reply(response)
  end

  # AI Conflict Mediator — analyzes both perspectives
  def mediate_conflict(topic:, user_name:, partner_name:, user_perspective:, partner_perspective:, language: "english", images: [])
    lang_instruction = if language == "hindi"
      "You MUST write your entire analysis and summary in Hindi (Devanagari script)."
    else
      "Write your analysis in English."
    end

    screenshot_instruction = if images.any?
      "Chat screenshots from WhatsApp/messaging apps are attached. Carefully read and analyze the conversation in the screenshots to understand the conflict, tone, and communication patterns. Use this as additional context alongside the written perspectives."
    else
      ""
    end

    system_content = <<~PROMPT
      You are an expert AI couples mediator. Analyze both partners' perspectives on a conflict without taking sides.
      #{lang_instruction}
      #{screenshot_instruction}
      Provide:
      1. A detailed analysis of BOTH perspectives equally, identifying underlying emotions and needs for each partner
      2. Common ground between the partners
      3. Specific, actionable recommendations for resolution
      #{"4. If chat screenshots are provided, analyze the communication patterns, tone, and key moments in the conversation that contributed to the conflict." if images.any?}

      IMPORTANT: You MUST complete the analysis for BOTH partners fully before writing the summary.

      Format your response in two clearly labeled sections (ALWAYS use these exact English labels, even if writing in Hindi):
      ANALYSIS: (detailed analysis covering both partners equally)
      SUMMARY: (a separate 2-3 sentence overall summary with key takeaway and recommendation)
    PROMPT

    # Build user message content (text + images)
    user_text = <<~MSG
      **Conflict Topic:** #{topic}

      **#{user_name}'s Perspective:**
      #{user_perspective}

      **#{partner_name}'s Perspective:**
      #{partner_perspective}

      Please provide a balanced mediation analysis.
    MSG

    if images.any?
      # Multimodal: text + images
      user_content = [{ type: "text", text: user_text }]
      images.each do |img|
        user_content << {
          type: "image_url",
          image_url: { url: "data:#{img[:mime_type]};base64,#{img[:base64]}" }
        }
      end
    else
      user_content = user_text
    end

    messages = [
      { role: "system", content: system_content },
      { role: "user", content: user_content }
    ]

    response = chat_with_retry(
      messages: messages,
      temperature: 0.6,
      max_tokens: 3000
    )

    reply = extract_reply(response)
    parse_mediation(reply)
  end

  # AI Compatibility Assessment — analyzes couple's compatibility from questionnaire
  def assess_compatibility(answers:)
    messages = [
      {
        role: "system",
        content: <<~PROMPT
          You are an expert relationship counselor and compatibility analyst. Based on the couple's questionnaire answers, provide a thorough compatibility assessment.

          You MUST respond with ONLY valid JSON (no markdown, no code fences, no extra text) in this exact structure:
          {
            "financial_score": <number 0-100>,
            "lifestyle_score": <number 0-100>,
            "parenting_score": <number 0-100>,
            "strengths": ["strength1", "strength2", "strength3", "strength4"],
            "risk_areas": ["risk1", "risk2", "risk3"],
            "full_report": "A detailed multi-paragraph compatibility report in markdown format covering financial compatibility, lifestyle compatibility, parenting/family compatibility, overall analysis, and specific actionable recommendations. Use ## headings for sections."
          }

          Guidelines for scoring:
          - Be realistic and nuanced — avoid giving all high or all low scores
          - Base scores on the actual answers provided, not random values
          - Strengths should highlight genuine positives from their answers
          - Risk areas should be constructive concerns, not criticisms
          - The full report should be personalized, referencing their specific answers
          - Include the partner's name throughout the report for personalization
        PROMPT
      },
      {
        role: "user",
        content: <<~ANSWERS
          Please analyze this couple's compatibility:

          Partner's Name: #{answers[:partner_name]}
          Relationship Duration: #{answers[:relationship_duration]&.humanize}

          **Financial:**
          - Financial approach: #{answers[:financial_approach]&.humanize}
          - Spending habits alignment: #{answers[:spending_habits]&.humanize}

          **Lifestyle:**
          - Social preference: #{answers[:social_preference]&.humanize}
          - Conflict handling style: #{answers[:conflict_style]&.humanize}

          **Parenting & Family:**
          - Children preference: #{answers[:children_preference]&.humanize}
          - Extended family involvement: #{answers[:family_involvement]&.humanize}

          **In Their Own Words:**
          - Strengths they see: #{answers[:strengths_text].presence || "Not provided"}
          - Concerns they have: #{answers[:concerns_text].presence || "Not provided"}
        ANSWERS
      }
    ]

    response = chat_with_retry(
      messages: messages,
      temperature: 0.6,
      max_tokens: 3000
    )

    reply = extract_reply(response)
    parse_compatibility(reply)
  end

  # AI Conversation Rewrite — rewrites messages to be calmer
  def rewrite_message(original_message, language: "english")
    lang_instruction = if language == "hindi"
      "You MUST write the rewritten message in Hindi (Devanagari script). The tone analysis JSON values should remain in English."
    else
      "Write the rewritten message in English."
    end

    messages = [
      {
        role: "system",
        content: <<~PROMPT
          You are an expert in emotionally intelligent communication for couples.
          #{lang_instruction}
          When given a message, provide:
          1. A rewritten version that is calmer, more respectful, and uses "I" statements while preserving the core intent
          2. A tone analysis in JSON format

          Format your response exactly as:
          REWRITE: (the rewritten message)
          TONE_JSON: {"original_tone": "...", "emotional_intensity": 0-100, "defensiveness_risk": 0-100, "constructiveness": 0-100, "suggested_approach": "..."}
        PROMPT
      },
      {
        role: "user",
        content: "Please rewrite this message to be more constructive:\n\n\"#{original_message}\""
      }
    ]
    response = chat_with_retry(
      messages: messages,
      temperature: 0.5,
      max_tokens: 800
    )

    reply = extract_reply(response)
    parse_rewrite(reply, original_message)
  end

  private

  def chat_with_retry(messages:, temperature:, max_tokens:)
    retries = 0
    begin
      @client.chat(
        parameters: {
          model: MODEL,
          messages: messages,
          temperature: temperature,
          max_tokens: max_tokens
        }
      )
    rescue Faraday::TooManyRequestsError => e
      retries += 1
      if retries <= MAX_RETRIES
        sleep_time = 2 ** retries
        Rails.logger.warn("Gemini 429 rate limit hit. Retrying in #{sleep_time}s (attempt #{retries}/#{MAX_RETRIES})")
        sleep(sleep_time)
        retry
      else
        raise e
      end
    end
  end

  def extract_reply(response)
    response.dig("choices", 0, "message", "content") || "I'm sorry, I couldn't generate a response. Please try again."
  end

  def parse_mediation(reply)
    # Try multiple possible labels (English, Hindi, markdown variations)
    summary_pattern = /\b(SUMMARY|Summary|सारांश|विश्लेषण सारांश)\s*[:：]/i
    analysis_pattern = /\b(ANALYSIS|Analysis|विश्लेषण)\s*[:：]/i

    if reply.match?(summary_pattern)
      parts = reply.split(summary_pattern)
      # Analysis is everything before the summary label
      analysis = parts[0].sub(analysis_pattern, "").strip
      # Summary is the last part after splitting
      summary = parts.last.strip
    elsif reply.include?("SUMMARY:")
      parts = reply.split("SUMMARY:")
      analysis = parts[0].sub("ANALYSIS:", "").strip
      summary = parts[1].strip
    else
      # Fallback: use full reply as analysis, generate a short summary from first paragraph
      analysis = reply.sub(analysis_pattern, "").strip
      paragraphs = analysis.split("\n\n").reject(&:blank?)
      summary = paragraphs.length > 1 ? paragraphs.last.first(300) : analysis.first(300)
    end
    { analysis: analysis, summary: summary }
  end

  def parse_rewrite(reply, original)
    if reply.include?("REWRITE:") && reply.include?("TONE_JSON:")
      parts = reply.split("TONE_JSON:")
      rewritten = parts[0].sub("REWRITE:", "").strip
      begin
        tone = JSON.parse(parts[1].strip)
        tone_analysis = {
          original_tone: tone["original_tone"] || "Unknown",
          emotional_intensity: tone["emotional_intensity"] || 50,
          defensiveness_risk: tone["defensiveness_risk"] || 50,
          constructiveness: tone["constructiveness"] || 50,
          suggested_approach: tone["suggested_approach"] || "Use 'I' statements and focus on feelings."
        }
      rescue JSON::ParserError
        tone_analysis = default_tone
      end
    else
      rewritten = reply
      tone_analysis = default_tone
    end
    { rewritten: rewritten, tone_analysis: tone_analysis }
  end

  def default_tone
    {
      original_tone: "Unknown",
      emotional_intensity: 50,
      defensiveness_risk: 50,
      constructiveness: 50,
      suggested_approach: "Express feelings using 'I' statements and focus on specific behaviors."
    }
  end

  def parse_compatibility(reply)
    # Strip markdown code fences if present
    cleaned = reply.gsub(/\A```(?:json)?\s*/, "").gsub(/\s*```\z/, "").strip
    data = JSON.parse(cleaned)

    {
      financial_score: data["financial_score"].to_f.clamp(0, 100).round(1),
      lifestyle_score: data["lifestyle_score"].to_f.clamp(0, 100).round(1),
      parenting_score: data["parenting_score"].to_f.clamp(0, 100).round(1),
      strengths: Array(data["strengths"]).first(5).join("\n• "),
      risk_areas: Array(data["risk_areas"]).first(4).join("\n• "),
      full_report: data["full_report"].to_s
    }
  rescue JSON::ParserError => e
    Rails.logger.error("Compatibility JSON parse error: #{e.message}")
    Rails.logger.error("Raw reply: #{reply}")
    default_compatibility
  end

  def default_compatibility
    {
      financial_score: 65.0,
      lifestyle_score: 65.0,
      parenting_score: 65.0,
      strengths: "We couldn't generate a detailed analysis at this time\n• Please try again for personalized results",
      risk_areas: "Assessment could not be completed\n• Please retry for accurate results",
      full_report: "We were unable to generate a detailed compatibility report. Please try again."
    }
  end
end

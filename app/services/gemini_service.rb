class GeminiService
  MODEL = "gemini-2.5-flash-lite"

  def initialize
    @client = OpenAI::Client.new
  end

  # AI Chat Assistant — sends full conversation history
  def chat(messages)
    response = @client.chat(
      parameters: {
        model: MODEL,
        messages: messages,
        temperature: 0.7,
        max_tokens: 1024
      }
    )
    extract_reply(response)
  end

  # AI Conflict Mediator — analyzes both perspectives
  def mediate_conflict(topic:, user_name:, partner_name:, user_perspective:, partner_perspective:)
    messages = [
      {
        role: "system",
        content: <<~PROMPT
          You are an expert AI couples mediator. Analyze both partners' perspectives on a conflict without taking sides.
          Provide:
          1. A detailed analysis of both perspectives, identifying underlying emotions and needs
          2. Common ground between the partners
          3. Specific, actionable recommendations for resolution

          Format your response in two clearly labeled sections:
          ANALYSIS: (detailed analysis)
          SUMMARY: (2-3 sentence summary)
        PROMPT
      },
      {
        role: "user",
        content: <<~MSG
          **Conflict Topic:** #{topic}

          **#{user_name}'s Perspective:**
          #{user_perspective}

          **#{partner_name}'s Perspective:**
          #{partner_perspective}

          Please provide a balanced mediation analysis.
        MSG
      }
    ]

    response = @client.chat(
      parameters: {
        model: MODEL,
        messages: messages,
        temperature: 0.6,
        max_tokens: 1500
      }
    )

    reply = extract_reply(response)
    parse_mediation(reply)
  end

  # AI Conversation Rewrite — rewrites messages to be calmer
  def rewrite_message(original_message)
    messages = [
      {
        role: "system",
        content: <<~PROMPT
          You are an expert in emotionally intelligent communication for couples.
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
    response = @client.chat(
      parameters: {
        model: MODEL,
        messages: messages,
        temperature: 0.5,
        max_tokens: 800
      }
    )

    reply = extract_reply(response)
    parse_rewrite(reply, original_message)
  end

  private

  def extract_reply(response)
    response.dig("choices", 0, "message", "content") || "I'm sorry, I couldn't generate a response. Please try again."
  end

  def parse_mediation(reply)
    if reply.include?("SUMMARY:")
      parts = reply.split("SUMMARY:")
      analysis = parts[0].sub("ANALYSIS:", "").strip
      summary = parts[1].strip
    else
      analysis = reply
      summary = reply.first(200)
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
end

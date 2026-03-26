class HealthScoreCalculatorService
  METRIC_TYPES = HealthMetric::METRIC_TYPES

  def initialize(user)
    @user = user
    @gemini = GeminiService.new
  end

  # Calculate and store health scores for the user
  def calculate!
    activity_data = gather_activity_data
    return nil if activity_data[:has_any_data] == false

    scores = request_ai_scores(activity_data)
    return nil unless scores

    save_scores(scores)
    scores
  end

  private

  def gather_activity_data
    current_period = 30.days.ago
    previous_period = 60.days.ago..30.days.ago

    # ── Conversations & Messages ──
    conversations = @user.conversations
    recent_conversations = conversations.where(created_at: current_period..)
    previous_conversations = conversations.where(created_at: previous_period)

    recent_messages = Message.joins(:conversation)
                            .where(conversations: { user_id: @user.id, created_at: current_period.. })
    user_messages = recent_messages.where(role: "user")
    previous_user_messages = Message.joins(:conversation)
                                   .where(conversations: { user_id: @user.id, created_at: previous_period })
                                   .where(role: "user")

    persona_counts = recent_conversations.group(:persona).count

    # Sample messages with timestamps for sentiment trend analysis
    sample_messages = user_messages.order(created_at: :desc).limit(20)
                                   .pluck(:content, :created_at)
                                   .map { |content, time| { text: content.truncate(200), date: time.strftime('%b %d') } }

    # ── Conflict Sessions (deep content) ──
    conflict_sessions = @user.conflict_sessions
    recent_conflicts = conflict_sessions.where(created_at: current_period..)
    previous_conflicts = conflict_sessions.where(created_at: previous_period)
    completed_conflicts = recent_conflicts.where(status: :completed)

    # Extract conflict content for pattern & quality analysis
    conflict_details = completed_conflicts.limit(5).map do |cs|
      {
        topic: cs.topic,
        user_perspective: cs.user_perspective&.truncate(300),
        partner_perspective: cs.partner_perspective&.truncate(300),
        ai_summary: cs.ai_summary&.truncate(300),
        has_both_perspectives: cs.user_perspective.present? && cs.partner_perspective.present?
      }
    end

    # Detect recurring conflict topics
    all_topics = conflict_sessions.pluck(:topic).compact
    topic_frequency = all_topics.tally.sort_by { |_, count| -count }

    # ── Expenses (pattern analysis) ──
    recent_expenses = @user.expenses.where(created_at: current_period..)
    previous_expenses = @user.expenses.where(created_at: previous_period)
    shared_expenses = recent_expenses.where(shared: true)
    previous_shared = previous_expenses.where(shared: true)

    shared_ratio_current = recent_expenses.any? ? (shared_expenses.count.to_f / recent_expenses.count * 100).round(1) : 0
    shared_ratio_previous = previous_expenses.any? ? (previous_shared.count.to_f / previous_expenses.count * 100).round(1) : 0

    # ── Memories (content quality) ──
    recent_memories = @user.memories.where(created_at: current_period..)
    previous_memories = @user.memories.where(created_at: previous_period)

    memory_details = recent_memories.limit(5).map do |m|
      { title: m.title, type: m.memory_type, description: m.description&.truncate(200) }
    end

    # ── Programs & Workshops ──
    active_programs = @user.user_programs.where(status: [:enrolled, :in_progress])
    completed_programs = @user.user_programs.where(status: :completed)
    workshop_registrations = @user.workshop_registrations.where(status: [:registered, :confirmed])

    # ── Compatibility Assessment ──
    latest_compatibility = @user.compatibility_assessments.where(status: :completed).order(created_at: :desc).first

    # ── Previous Health Scores (for trend comparison) ──
    previous_scores = {}
    HealthMetric::METRIC_TYPES.each do |type|
      prev = @user.health_metrics.by_type(type).where(created_at: previous_period).order(created_at: :desc).first
      previous_scores[type] = prev&.score
    end

    has_any_data = recent_conversations.any? || recent_conflicts.any? || recent_expenses.any? ||
                   recent_memories.any? || active_programs.any? || completed_programs.any? ||
                   workshop_registrations.any? || latest_compatibility.present?

    {
      has_any_data: has_any_data,

      # Conversation data with trend
      recent_conversation_count: recent_conversations.count,
      previous_conversation_count: previous_conversations.count,
      recent_message_count: user_messages.count,
      previous_message_count: previous_user_messages.count,
      persona_usage: persona_counts,
      sample_messages: sample_messages,

      # Conflict data with content
      recent_conflict_count: recent_conflicts.count,
      previous_conflict_count: previous_conflicts.count,
      completed_conflict_count: completed_conflicts.count,
      pending_conflict_count: recent_conflicts.where.not(status: :completed).count,
      conflict_details: conflict_details,
      recurring_topics: topic_frequency.first(5),

      # Financial data with trend
      recent_expense_count: recent_expenses.count,
      shared_expense_count: shared_expenses.count,
      shared_ratio_current: shared_ratio_current,
      shared_ratio_previous: shared_ratio_previous,
      expense_categories: recent_expenses.group(:category).count,

      # Memory data with content
      recent_memory_count: recent_memories.count,
      previous_memory_count: previous_memories.count,
      memory_details: memory_details,

      # Programs & workshops
      active_program_count: active_programs.count,
      completed_program_count: completed_programs.count,
      workshop_count: workshop_registrations.count,

      # Compatibility
      compatibility: if latest_compatibility
                       {
                         financial_score: latest_compatibility.financial_score,
                         lifestyle_score: latest_compatibility.lifestyle_score,
                         parenting_score: latest_compatibility.parenting_score,
                         overall: latest_compatibility.overall_score,
                         strengths: latest_compatibility.strengths&.truncate(300),
                         risk_areas: latest_compatibility.risk_areas&.truncate(300)
                       }
                     end,

      # Previous scores for trend
      previous_scores: previous_scores
    }
  end

  # Send activity data to Gemini for AI-powered scoring
  def request_ai_scores(activity_data)
    messages = [
      { role: "system", content: scoring_prompt },
      { role: "user", content: format_activity_data(activity_data) }
    ]

    response = @gemini.send(:chat_with_retry,
      messages: messages,
      temperature: 0.4,
      max_tokens: 2000
    )

    reply = @gemini.send(:extract_reply, response)
    parse_scores(reply)
  rescue => e
    Rails.logger.error("HealthScoreCalculator AI error: #{e.message}")
    nil
  end

  def scoring_prompt
    <<~PROMPT
      You are an expert relationship psychologist analyzing a couple's relationship health through their interactions on CoupleLens, a couples wellness platform where users chat with AI counselors via Telegram/WhatsApp.

      Your job is NOT to measure app usage. Your job is to assess ACTUAL RELATIONSHIP HEALTH by analyzing the CONTENT and PATTERNS of their interactions.

      ANALYZE THESE SIGNALS:

      **Communication (0-100)** — Assess the QUALITY of how this person communicates:
      - Read their actual messages: Do they use "I" statements? Show empathy? Express needs clearly?
      - Are messages emotionally mature or reactive/defensive/blaming?
      - Is there emotional vocabulary (naming feelings) or avoidance?
      - TREND: Are messages becoming more constructive over time, or deteriorating?
      - Choosing "communication_expert" persona = self-awareness about communication gaps

      **Trust (0-100)** — Assess the LEVEL OF OPENNESS and vulnerability:
      - In conflict sessions: Did they honestly share their perspective AND fairly represent their partner's side? Or is it one-sided/blaming?
      - Financial transparency: Are expenses tracked openly and shared proportionally?
      - Are they willing to discuss difficult topics with the AI counselor?
      - TREND: Is the shared expense ratio growing or shrinking compared to previous period?

      **Conflict Resolution (0-100)** — Assess RESOLUTION ABILITY, not just usage:
      - Do conflicts get COMPLETED (resolved) or left PENDING (abandoned)?
      - READ the conflict summaries: Are solutions being found? Is common ground identified?
      - CRITICAL: Are the SAME TOPICS recurring? Recurring = unresolved core issue = LOW score
      - Are both perspectives provided? One-sided = low willingness to understand partner
      - TREND: Fewer new conflicts over time = improving, same conflicts repeating = worsening

      **Intimacy (0-100)** — Assess EMOTIONAL CONNECTION quality:
      - Read memory descriptions: Are they surface-level ("went to dinner") or emotionally rich ("felt so connected when...")?
      - Memory types matter: milestones, anniversaries, date_nights show intentional bonding
      - Conversation depth with counselor: Are they exploring deep emotional topics or just surface issues?
      - TREND: More emotional memories over time = growing connection

      **Shared Goals (0-100)** — Assess ALIGNMENT and joint investment:
      - Programs/workshops = actively working on relationship together
      - Shared expense ratio = financial partnership level
      - Compatibility assessment strengths vs risk areas
      - TREND: Is shared financial ratio improving? Are they enrolling in growth activities?

      SCORING RULES:
      - ZERO activity for a dimension = score MUST be 0
      - Focus on CONTENT QUALITY over quantity. 3 deep, emotionally mature messages > 20 shallow "hi" messages
      - TRENDS matter: Improvement over previous period = higher score; decline = lower score
      - Previous scores are provided for context — use them to track trajectory
      - Be specific in notes — reference actual content patterns you observed

      You MUST respond with ONLY valid JSON (no markdown, no code fences, no extra text):
      {
        "communication": {"score": <0-100>, "note": "<2-3 sentence explanation citing specific content patterns>"},
        "trust": {"score": <0-100>, "note": "<2-3 sentence explanation citing specific content patterns>"},
        "conflict_resolution": {"score": <0-100>, "note": "<2-3 sentence explanation citing specific content patterns>"},
        "intimacy": {"score": <0-100>, "note": "<2-3 sentence explanation citing specific content patterns>"},
        "shared_goals": {"score": <0-100>, "note": "<2-3 sentence explanation citing specific content patterns>"}
      }
    PROMPT
  end

  def format_activity_data(data)
    parts = []
    parts << "=== RELATIONSHIP DATA FOR ANALYSIS ==="

    # ── Communication Content ──
    parts << ""
    parts << "## COMMUNICATION DATA"
    parts << "Current period (30d): #{data[:recent_conversation_count]} conversations, #{data[:recent_message_count]} messages"
    parts << "Previous period (30-60d ago): #{data[:previous_conversation_count]} conversations, #{data[:previous_message_count]} messages"
    parts << "Trend: #{trend_label(data[:recent_message_count], data[:previous_message_count])}"
    parts << "AI persona choices: #{data[:persona_usage].map { |k, v| "#{k}: #{v}" }.join(', ').presence || 'None'}"

    if data[:sample_messages].any?
      parts << ""
      parts << "### Actual Messages (analyze tone, emotional maturity, communication style):"
      data[:sample_messages].each_with_index do |m, i|
        parts << "  #{i + 1}. [#{m[:date]}] \"#{m[:text]}\""
      end
    else
      parts << "No messages sent."
    end

    # ── Conflict Content ──
    parts << ""
    parts << "## CONFLICT DATA"
    parts << "Current period: #{data[:recent_conflict_count]} sessions (#{data[:completed_conflict_count]} completed, #{data[:pending_conflict_count]} pending)"
    parts << "Previous period: #{data[:previous_conflict_count]} sessions"
    parts << "Trend: #{trend_label(data[:recent_conflict_count], data[:previous_conflict_count], inverse: true)}"

    if data[:recurring_topics].any?
      parts << ""
      parts << "### Topic Frequency (recurring = unresolved issues):"
      data[:recurring_topics].each { |topic, count| parts << "  - \"#{topic}\" — appeared #{count} time(s)" }
    end

    if data[:conflict_details].any?
      parts << ""
      parts << "### Conflict Content (analyze perspectives, balance, resolution quality):"
      data[:conflict_details].each_with_index do |c, i|
        parts << "  --- Conflict #{i + 1}: #{c[:topic]} ---"
        parts << "  User's perspective: \"#{c[:user_perspective] || 'Not provided'}\""
        parts << "  Partner's perspective: \"#{c[:partner_perspective] || 'Not provided'}\""
        parts << "  Both sides provided: #{c[:has_both_perspectives]}"
        parts << "  AI mediation summary: \"#{c[:ai_summary] || 'Not available'}\""
        parts << ""
      end
    else
      parts << "No conflict sessions."
    end

    # ── Financial Transparency ──
    parts << ""
    parts << "## FINANCIAL DATA"
    parts << "Current period: #{data[:recent_expense_count]} expenses (#{data[:shared_expense_count]} shared, #{data[:shared_ratio_current]}% shared)"
    parts << "Previous period shared ratio: #{data[:shared_ratio_previous]}%"
    parts << "Trend: #{trend_label(data[:shared_ratio_current], data[:shared_ratio_previous])}"
    if data[:expense_categories].any?
      parts << "Categories: #{data[:expense_categories].map { |k, v| "#{k}: #{v}" }.join(', ')}"
    end

    # ── Intimacy & Emotional Connection ──
    parts << ""
    parts << "## INTIMACY DATA"
    parts << "Current period: #{data[:recent_memory_count]} memories"
    parts << "Previous period: #{data[:previous_memory_count]} memories"
    parts << "Trend: #{trend_label(data[:recent_memory_count], data[:previous_memory_count])}"

    if data[:memory_details].any?
      parts << ""
      parts << "### Memory Content (analyze emotional depth):"
      data[:memory_details].each_with_index do |m, i|
        parts << "  #{i + 1}. [#{m[:type]}] \"#{m[:title]}\" — #{m[:description] || 'No description'}"
      end
    else
      parts << "No memories created."
    end

    # ── Shared Goals ──
    parts << ""
    parts << "## SHARED GOALS DATA"
    parts << "Active programs: #{data[:active_program_count]}"
    parts << "Completed programs: #{data[:completed_program_count]}"
    parts << "Workshop registrations: #{data[:workshop_count]}"

    if data[:compatibility]
      parts << ""
      parts << "### Compatibility Assessment:"
      parts << "  Financial: #{data[:compatibility][:financial_score]}, Lifestyle: #{data[:compatibility][:lifestyle_score]}, Parenting: #{data[:compatibility][:parenting_score]}"
      parts << "  Strengths: #{data[:compatibility][:strengths] || 'N/A'}"
      parts << "  Risk areas: #{data[:compatibility][:risk_areas] || 'N/A'}"
    end

    # ── Previous Scores for Trend ──
    if data[:previous_scores].values.compact.any?
      parts << ""
      parts << "## PREVIOUS HEALTH SCORES (for trajectory analysis)"
      data[:previous_scores].each do |type, score|
        parts << "  #{type}: #{score || 'No previous score'}"
      end
    end

    parts.join("\n")
  end

  def trend_label(current, previous, inverse: false)
    return "No previous data" if previous.nil? || previous == 0
    diff = current - previous
    if inverse
      # For conflicts: fewer = better
      if diff < 0 then "Improving (fewer conflicts)"
      elsif diff > 0 then "Worsening (more conflicts)"
      else "Stable"
      end
    else
      if diff > 0 then "Improving (+#{diff})"
      elsif diff < 0 then "Declining (#{diff})"
      else "Stable"
      end
    end
  end

  def parse_scores(reply)
    # Clean any markdown code fences
    cleaned = reply.gsub(/```json\s*/, "").gsub(/```\s*/, "").strip
    data = JSON.parse(cleaned)

    scores = {}
    METRIC_TYPES.each do |type|
      key = type.to_s
      if data[key]
        score = data[key]["score"].to_f.clamp(0, 100)
        note = data[key]["note"].to_s.truncate(500)
        scores[type] = { score: score, note: note }
      end
    end

    scores.size == METRIC_TYPES.size ? scores : nil
  rescue JSON::ParserError => e
    Rails.logger.error("HealthScoreCalculator JSON parse error: #{e.message}")
    nil
  end

  def save_scores(scores)
    scores.each do |metric_type, data|
      @user.health_metrics.create!(
        metric_type: metric_type,
        score: data[:score],
        notes: data[:note],
        recorded_at: Time.current
      )
    end
  end
end

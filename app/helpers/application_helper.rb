module ApplicationHelper
  def user_avatar(user, size: 40, css_class: "", alt: nil)
    avatar_style = "width: #{size}px; height: #{size}px; border-radius: 50%; object-fit: cover;"

    if user&.profile_image&.attached?
      image_tag(
        user.profile_image,
        alt: alt || "#{user.full_name} profile image",
        class: css_class,
        style: avatar_style
      )
    else
      content_tag(
        :div,
        user_initials(user),
        class: "d-inline-flex align-items-center justify-content-center #{css_class}",
        style: "#{avatar_style} background: linear-gradient(135deg, #6C63FF, #FF6B9D); color: #fff; font-weight: 700;"
      )
    end
  end

  def user_initials(user)
    first = user&.first_name.to_s.first
    last = user&.last_name.to_s.first
    initials = "#{first}#{last}".upcase
    initials.present? ? initials : "U"
  end

  # Formats AI-generated text for better readability
  def format_ai_response(text)
    return "" if text.blank?

    # 1. Normalize bullet bolds: 
    # AI sometimes outputs: "**1. Point**" or "**1.** Point"
    # Case: **1. Point** -> 1. **Point**
    text = text.gsub(/^\s*\*\*\s*([*\-•]|\d+\.)\s*(.*?)\*\*\s*$/, '\1 **\2**')
    # Case: **1.** Point -> 1. Point
    text = text.gsub(/^\s*\*\*\s*([*\-•]|\d+\.)\s*\*\*\s*(.*)$/, '\1 \2')

    # 2. Extract lists
    text = text.gsub(/^\s*([*\-•]|\d+\.)\s+(.*)$/) do
      bullet = $1
      content = $2
      type = bullet.match?(/\d+/) ? "ol" : "ul"
      "<!-- #{type} --><li class=\"mb-2\">#{content}</li>"
    end
    
    # Wrap lists
    text = text.gsub(/(?:<!-- (ul|ol) --><li[^>]*>.*?<\/li>[ \t]*\n?)+/) do |match|
      tag = match.include?("<!-- ol -->") ? "ol" : "ul"
      clean = match.gsub(/<!-- (ul|ol) -->/, "")
      "<#{tag} class='mb-4 ps-4'>\n#{clean}</#{tag}>\n"
    end

    # 1. Handle Headings (Markdown style)
    text = text.gsub(/^# (.*)$/, '<h2 class="fw-bold mt-4 mb-3 gradient-text">\1</h2>')
    text = text.gsub(/^## (.*)$/, '<h3 class="fw-bold mt-4 mb-3" style="color: #6C63FF; border-left: 4px solid #6C63FF; padding-left: 1rem;">\1</h3>')
    text = text.gsub(/^### (.*)$/, '<h4 class="fw-bold mt-3 mb-2" style="color: #FF6B9D;">\1</h4>')

    # 2. Handle common section labels (e.g., "Summary:", "Analysis:")
    labels = %w[Summary Analysis Recommendations Strengths Risks Conclusion सारांश विश्लेषण सुझाव]
    labels.each do |label|
      text = text.gsub(/^#{label}[:：]\s*(.*)$/i, "<div class='mt-3 mb-2'><strong class='text-primary fw-bold'><i class='bi bi-chevron-right me-1'></i>#{label}:</strong> \\1</div>")
    end

    # 3. Handle bold markdown (**text**)
    text = text.gsub(/\*\*(.*?)\*\*/, '<strong class="fw-bold text-white">\1</strong>')

    # 6. Apply simple_format and sanitize
    formatted = simple_format(text, {}, sanitize: false)
    formatted = formatted.gsub(/<p>\s*<\/p>/, '')
    
    sanitize(formatted, tags: %w[h2 h3 h4 strong ul ol li div p i span], attributes: %w[class style])
  end
end

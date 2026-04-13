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
end

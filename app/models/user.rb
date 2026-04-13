class User < ApplicationRecord
  ALLOWED_PROFILE_IMAGE_TYPES = %w[image/png image/jpeg image/jpg image/webp image/gif].freeze
  MAX_PROFILE_IMAGE_SIZE = 5.megabytes

  # Remove :validatable — we add validations manually to scope email uniqueness by role
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  # Roles
  enum role: { couple_member: 0, therapist: 1, admin: 2 }

  has_one_attached :profile_image

  # Partner relationship
  belongs_to :partner, class_name: 'User', optional: true

  # AI Features
  has_many :conversations, dependent: :destroy
  has_many :conflict_sessions, dependent: :destroy

  # Health & Compatibility
  has_many :health_metrics, dependent: :destroy
  has_many :compatibility_assessments, dependent: :destroy

  # Therapist
  has_one :therapist_profile, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_one :therapist_application, dependent: :destroy

  # Financial
  has_many :expenses, dependent: :destroy
  has_one :financial_profile, dependent: :destroy

  # Memories
  has_many :memories, dependent: :destroy

  # Programs
  has_many :user_programs, dependent: :destroy
  has_many :programs, through: :user_programs

  # Workshops
  has_many :workshop_registrations, dependent: :destroy
  has_many :workshops, through: :workshop_registrations

  # Validations (replaces Devise :validatable, with email uniqueness scoped by role)
  validates :email, presence: true, format: { with: Devise.email_regexp }, uniqueness: { scope: :role, case_sensitive: false }
  validates :password, presence: true, confirmation: true, length: { within: Devise.password_length }, if: :password_required?
  validates :first_name, presence: true
  validates :last_name, presence: true
  validate :profile_image_type_and_size

  after_initialize :set_default_role, if: :new_record?

  def self.from_omniauth(auth, role: nil)
    target_role = (role == 'therapist') ? :therapist : :couple_member

    user = find_by(email: auth.info.email, role: target_role)
    if user
      user.update(provider: auth.provider, uid: auth.uid) unless user.provider
      user
    else
      user = create(
        email: auth.info.email,
        provider: auth.provider,
        uid: auth.uid,
        first_name: auth.info.first_name || auth.info.name&.split(' ')&.first || 'User',
        last_name: auth.info.last_name || auth.info.name&.split(' ')&.last || '',
        password: Devise.friendly_token[0, 20],
        role: target_role
      )

      if target_role == :therapist && user.persisted?
        user.create_therapist_application!(
          full_name: user.full_name,
          email: user.email,
          specialization: 'General Counseling',
          bio: 'Pending - please update your profile',
          certifications: 'Pending - please update',
          years_experience: 0,
          hourly_rate: 0,
          status: :submitted
        )
      end

      user
    end
  end

  def oauth_user?
    provider.present?
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def admin?
    role == 'admin'
  end

  def therapist?
    role == 'therapist'
  end

  def couple_member?
    role == 'couple_member'
  end

  def generate_bot_link_code!
    code = "CL-#{SecureRandom.alphanumeric(6).upcase}"
    update!(bot_link_code: code, bot_link_code_expires_at: 30.minutes.from_now)
    code
  end

  def bot_linked?
    telegram_id.present? || whatsapp_id.present?
  end

  private

  # Replaces Devise :validatable's password_required? — skip for OAuth users
  def password_required?
    return false if oauth_user?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  def set_default_role
    self.role ||= :couple_member
  end

  def profile_image_type_and_size
    return unless profile_image.attached?

    unless ALLOWED_PROFILE_IMAGE_TYPES.include?(profile_image.blob.content_type)
      errors.add(:profile_image, "must be a PNG, JPG, WEBP, or GIF")
    end

    if profile_image.blob.byte_size > MAX_PROFILE_IMAGE_SIZE
      errors.add(:profile_image, "must be smaller than 5MB")
    end
  end
end

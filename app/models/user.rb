class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Roles
  enum role: { couple_member: 0, therapist: 1, admin: 2 }

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

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true

  after_initialize :set_default_role, if: :new_record?

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

  def set_default_role
    self.role ||= :couple_member
  end
end

class Conversation < ApplicationRecord
  include Slugable

  belongs_to :user
  has_many :messages, dependent: :destroy

  enum status: { active: 0, archived: 1 }
  enum persona: {
    clinical_psychologist: 'clinical_psychologist',
    empathetic_listener: 'empathetic_listener',
    relationship_coach: 'relationship_coach',
    communication_expert: 'communication_expert'
  }

  PLATFORMS = %w[web telegram whatsapp].freeze

  validates :title, presence: { message: "Please enter a topic for your conversation" }
  validates :platform, inclusion: { in: PLATFORMS }, allow_nil: true

  scope :by_platform, ->(platform) { where(platform: platform) }
  scope :from_messaging, -> { where(platform: %w[telegram whatsapp]) }

  after_initialize :set_defaults, if: :new_record?

  def persona_display_name
    persona&.titleize || 'AI Assistant'
  end

  def persona_icon
    case persona
    when 'clinical_psychologist' then '🧠'
    when 'empathetic_listener' then '💝'
    when 'relationship_coach' then '🎯'
    when 'communication_expert' then '💬'
    else '🤖'
    end
  end

  private

  def set_defaults
    self.status ||= :active
    # Only auto-assign agent for web conversations; messaging users should pick their own
    self.persona ||= :empathetic_listener unless platform.in?(%w[telegram whatsapp])
  end
end

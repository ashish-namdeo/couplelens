class Conversation < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy

  enum status: { active: 0, archived: 1 }
  enum persona: {
    clinical_psychologist: 'clinical_psychologist',
    empathetic_listener: 'empathetic_listener',
    relationship_coach: 'relationship_coach',
    communication_expert: 'communication_expert'
  }

  validates :title, presence: true

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
    self.persona ||= :empathetic_listener
  end
end

class ConflictSession < ApplicationRecord
  belongs_to :user

  has_many_attached :chat_screenshots

  enum status: { pending_partner: 0, analyzing: 1, completed: 2 }

  validates :topic, presence: true
  validate :perspective_or_screenshots_present

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.status ||= :pending_partner
  end

  def perspective_or_screenshots_present
    if user_perspective.blank? && !chat_screenshots.attached?
      errors.add(:base, "Please provide your perspective or upload chat screenshots")
    end
  end
end

class ConflictSession < ApplicationRecord
  belongs_to :user

  enum status: { pending_partner: 0, analyzing: 1, completed: 2 }

  validates :topic, presence: true
  validates :user_perspective, presence: true

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.status ||= :pending_partner
  end
end

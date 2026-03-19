class Message < ApplicationRecord
  belongs_to :conversation

  validates :role, presence: true, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true

  scope :ordered, -> { order(created_at: :asc) }
end

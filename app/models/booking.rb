class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :therapist_profile

  enum status: { pending: 0, confirmed: 1, completed: 2, cancelled: 3 }
  enum session_type: { video: 'video', voice: 'voice', chat: 'chat' }

  validates :scheduled_at, presence: true
  validates :duration, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }

  scope :upcoming, -> { where('scheduled_at > ?', Time.current).order(scheduled_at: :asc) }
  scope :past, -> { where('scheduled_at <= ?', Time.current).order(scheduled_at: :desc) }

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.status ||= :pending
    self.duration ||= 60
  end
end

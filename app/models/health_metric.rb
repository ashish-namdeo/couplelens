class HealthMetric < ApplicationRecord
  belongs_to :user

  validates :metric_type, presence: true
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :recent, -> { order(recorded_at: :desc) }
  scope :by_type, ->(type) { where(metric_type: type) }

  METRIC_TYPES = %w[communication trust conflict_resolution intimacy shared_goals].freeze

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.recorded_at ||= Time.current
  end
end

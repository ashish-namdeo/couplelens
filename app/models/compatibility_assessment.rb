class CompatibilityAssessment < ApplicationRecord
  include Slugable

  belongs_to :user

  enum status: { pending: 0, in_progress: 1, completed: 2 }

  validates :partner_name, presence: true

  after_initialize :set_defaults, if: :new_record?

  def overall_calculated_score
    scores = [financial_score, lifestyle_score, parenting_score].compact
    return 0 if scores.empty?
    (scores.sum / scores.length).round(1)
  end

  private

  def set_defaults
    self.status ||= :pending
  end
end

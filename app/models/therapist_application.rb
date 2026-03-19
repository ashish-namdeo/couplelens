class TherapistApplication < ApplicationRecord
  belongs_to :user

  enum status: { submitted: 0, under_review: 1, approved: 2, rejected: 3 }

  validates :full_name, presence: true
  validates :email, presence: true
  validates :specialization, presence: true
  validates :bio, presence: true

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.status ||= :submitted
  end
end

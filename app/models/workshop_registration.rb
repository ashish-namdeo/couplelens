class WorkshopRegistration < ApplicationRecord
  belongs_to :user
  belongs_to :workshop

  enum status: { registered: 0, confirmed: 1, cancelled: 2 }

  validates :amount_paid, presence: true, numericality: { greater_than_or_equal_to: 0 }

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.status ||= :registered
  end
end

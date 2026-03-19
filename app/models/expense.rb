class Expense < ApplicationRecord
  belongs_to :user

  validates :category, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true

  CATEGORIES = %w[Housing Food Transportation Entertainment Health Education Shopping Travel Utilities Other].freeze

  scope :recent, -> { order(expense_date: :desc) }
  scope :shared_expenses, -> { where(shared: true) }
  scope :this_month, -> { where(expense_date: Date.current.beginning_of_month..Date.current.end_of_month) }

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.expense_date ||= Date.current
    self.shared ||= false
  end
end

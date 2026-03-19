class FinancialProfile < ApplicationRecord
  belongs_to :user

  SPENDING_STYLES = %w[Saver Balanced Spender].freeze
  FINANCIAL_PERSONALITIES = %w[Conservative Moderate Aggressive].freeze

  validates :monthly_income, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :savings_goal, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end

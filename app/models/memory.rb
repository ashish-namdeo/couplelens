class Memory < ApplicationRecord
  belongs_to :user
  has_one_attached :photo

  validates :title, presence: true
  validates :memory_date, presence: true

  MEMORY_TYPES = %w[milestone anniversary trip surprise date_night achievement other].freeze

  scope :recent, -> { order(memory_date: :desc) }

  def memory_icon
    case memory_type
    when 'milestone' then '🏆'
    when 'anniversary' then '💍'
    when 'trip' then '✈️'
    when 'surprise' then '🎁'
    when 'date_night' then '🌙'
    when 'achievement' then '⭐'
    else '💝'
    end
  end
end

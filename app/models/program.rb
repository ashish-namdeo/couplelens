class Program < ApplicationRecord
  has_many :lessons, dependent: :destroy
  has_many :user_programs, dependent: :destroy
  has_many :users, through: :user_programs

  enum status: { draft: 0, published: 1, archived: 2 }

  CATEGORIES = ['Trust Rebuilding', 'Pre-Marriage Preparation', 'Communication Skills',
                'Conflict Resolution', 'Intimacy Enhancement', 'Financial Harmony'].freeze
  DIFFICULTIES = %w[Beginner Intermediate Advanced].freeze

  validates :title, presence: true
  validates :description, presence: true

  scope :published, -> { where(status: :published) }

  after_initialize :set_defaults, if: :new_record?

  def progress_for(user)
    up = user_programs.find_by(user: user)
    return 0 unless up
    total = lessons.count
    return 0 if total.zero?
    ((up.current_lesson.to_f / total) * 100).round
  end

  private

  def set_defaults
    self.status ||= :published
  end
end

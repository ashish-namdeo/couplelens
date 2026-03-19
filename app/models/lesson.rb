class Lesson < ApplicationRecord
  belongs_to :program

  validates :title, presence: true
  validates :content, presence: true
  validates :position, presence: true

  scope :ordered, -> { order(position: :asc) }
end

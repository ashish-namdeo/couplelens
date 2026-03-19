class Workshop < ApplicationRecord
  has_many :workshop_registrations, dependent: :destroy
  has_many :users, through: :workshop_registrations

  enum status: { upcoming: 0, ongoing: 1, completed: 2, cancelled: 3 }
  enum workshop_type: { online: 'online', in_person: 'in_person', retreat: 'retreat' }

  validates :title, presence: true
  validates :description, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :capacity, presence: true, numericality: { greater_than: 0 }

  scope :upcoming_events, -> { where(status: :upcoming).order(workshop_date: :asc) }

  after_initialize :set_defaults, if: :new_record?

  def spots_remaining
    (capacity || 0) - (spots_taken || 0)
  end

  def sold_out?
    spots_remaining <= 0
  end

  private

  def set_defaults
    self.status ||= :upcoming
    self.spots_taken ||= 0
  end
end

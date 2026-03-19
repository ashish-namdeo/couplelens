class TherapistProfile < ApplicationRecord
  belongs_to :user
  has_many :bookings, dependent: :destroy

  enum status: { pending: 0, approved: 1, suspended: 2 }

  validates :specialization, presence: true
  validates :bio, presence: true
  validates :hourly_rate, presence: true, numericality: { greater_than: 0 }

  scope :approved, -> { where(status: :approved) }
  scope :by_specialization, ->(spec) { where(specialization: spec) }

  SPECIALIZATIONS = [
    'Gottman Method', 'Emotionally Focused Therapy (EFT)',
    'Cognitive Behavioral Therapy (CBT)', 'Imago Relationship Therapy',
    'Narrative Therapy', 'Solution-Focused Therapy',
    'Psychodynamic Therapy', 'General Couples Therapy'
  ].freeze

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.status ||= :pending
    self.rating ||= 0.0
  end
end

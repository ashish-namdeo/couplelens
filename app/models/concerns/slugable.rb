module Slugable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug, on: :create
    validates :slug, presence: true, uniqueness: true
  end

  def to_param
    slug
  end

  private

  def generate_slug
    return if slug.present?
    self.slug = SecureRandom.hex(8)
  end
end

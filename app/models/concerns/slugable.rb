module Slugable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug, on: :create
    after_find :ensure_slug!
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

  def ensure_slug!
    return if slug.present?
    update_column(:slug, SecureRandom.hex(8))
  end
end

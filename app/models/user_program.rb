class UserProgram < ApplicationRecord
  belongs_to :user
  belongs_to :program

  enum status: { enrolled: 0, in_progress: 1, completed: 2 }

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.status ||= :enrolled
    self.current_lesson ||= 0
    self.started_at ||= Time.current
  end
end

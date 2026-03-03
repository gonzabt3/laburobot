class Report < ApplicationRecord
  REASONS = %w[spam abuse inappropriate fake_profile other].freeze

  enum :status, { pending: 0, reviewed: 1, resolved: 2, dismissed: 3 }, prefix: true

  belongs_to :reporter_user, class_name: "User"
  belongs_to :target_user, class_name: "User"

  validates :reporter_user, presence: true
  validates :target_user, presence: true
  validates :reason, presence: true, inclusion: { in: REASONS }
  validates :status, presence: true

  before_validation :set_defaults

  private

  def set_defaults
    self.status ||= :pending
  end
end

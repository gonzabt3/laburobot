class Rating < ApplicationRecord
  belongs_to :lead

  validates :lead, presence: true
  validates :score, presence: true, inclusion: { in: 1..5 }
  validates :lead_id, uniqueness: true
end

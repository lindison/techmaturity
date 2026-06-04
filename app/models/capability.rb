# A single thing being assessed within a dimension (e.g. "Test Suite",
# "Error Budgets"), with four maturity levels and an optional min target.
class Capability < ApplicationRecord
  belongs_to :dimension
  has_many :capability_levels, -> { order(:value) }, dependent: :destroy
  has_many :assessment_responses, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :dimension_id }

  delegate :framework, to: :dimension

  def level(value)
    capability_levels.detect { |l| l.value == value.to_i }
  end
end

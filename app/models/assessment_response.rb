# One capability's chosen level (1-4) within an assessment.
class AssessmentResponse < ApplicationRecord
  belongs_to :assessment
  belongs_to :capability

  validates :value, inclusion: { in: 1..4 }, allow_nil: true
  validates :capability_id, uniqueness: { scope: :assessment_id }
end

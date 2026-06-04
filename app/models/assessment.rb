# A scored evaluation of a product against a framework. Replaces the old wide
# Score row: one Assessment has many responses (one per capability).
class Assessment < ApplicationRecord
  belongs_to :product
  belongs_to :framework
  has_many :assessment_responses, dependent: :destroy
  accepts_nested_attributes_for :assessment_responses

  scope :latest, -> { where(latest: true) }

  def value_for(capability)
    responses_by_capability[capability.id]&.value
  end

  def responses_by_capability
    @responses_by_capability ||= assessment_responses.index_by(&:capability_id)
  end

  # Average answered level (0-4) for a dimension.
  def dimension_average(dimension)
    values = dimension.capabilities.filter_map { |capability| value_for(capability) }
    values.empty? ? 0.0 : values.sum.to_f / values.size
  end

  # "Cloud-readiness" style %: share of target capabilities meeting min_level.
  def readiness
    targeted = framework.capabilities.to_a.select { |c| c.min_level.present? }
    return 0.0 if targeted.empty?

    met = targeted.count { |c| (value_for(c) || 0) >= c.min_level }
    (met.to_f / targeted.size) * 100
  end
end

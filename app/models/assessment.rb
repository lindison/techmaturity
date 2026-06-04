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
  alias_method :total, :readiness

  # --- chart series (ordered by the framework's dimensions/capabilities) ---

  def capability_values
    framework.capabilities.map { |capability| value_for(capability) || 0 }
  end

  def dimension_values
    ordered_dimensions.map { |dimension| dimension_average(dimension) }
  end

  # One value per capability, set to that capability's dimension average
  # (used for the category overlay line).
  def expanded_dimension_values
    ordered_dimensions.flat_map do |dimension|
      avg = dimension_average(dimension)
      Array.new(dimension.capabilities.size, avg)
    end
  end

  # Make this the current assessment for its (product, framework).
  def make_latest!
    product.assessments.where(framework_id: framework_id).where.not(id: id).update_all(latest: false)
    update_column(:latest, true)
  end

  # --- organization-wide averages across the latest assessments in a framework ---

  def self.org_capability_values(framework)
    averages = AssessmentResponse.where(assessment_id: framework.assessments.latest.select(:id))
                                 .group(:capability_id).average(:value)
    framework.capabilities.map { |capability| (averages[capability.id] || 0).to_f }
  end

  def self.org_dimension_values(framework)
    latest = framework.assessments.latest.select(:id)
    framework.dimensions.order(:position).map do |dimension|
      avg = AssessmentResponse.where(assessment_id: latest, capability_id: dimension.capabilities.select(:id))
                              .average(:value)
      (avg || 0).to_f
    end
  end

  # Per-capability org average, but each capability carries its dimension's
  # average (for the category overlay line).
  def self.org_expanded_dimension_values(framework)
    dimension_values = org_dimension_values(framework)
    framework.dimensions.order(:position).each_with_index.flat_map do |dimension, i|
      Array.new(dimension.capabilities.size, dimension_values[i])
    end
  end

  def self.org_readiness(framework)
    latest = framework.assessments.latest.to_a
    return 0.0 if latest.empty?

    latest.sum(&:readiness) / latest.size
  end

  private

  def ordered_dimensions
    framework.dimensions.order(:position).includes(:capabilities)
  end
end

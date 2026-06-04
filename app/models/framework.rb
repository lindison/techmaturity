# A maturity model (e.g. Tech, SRE, Kubernetes/Cloud-Native). Owns the
# dimensions/capabilities/levels that an Assessment scores against.
class Framework < ApplicationRecord
  has_many :dimensions, -> { order(:position) }, dependent: :destroy
  has_many :assessments, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :ordered, -> { order(:position, :name) }

  def self.default
    find_by(slug: "tech") || ordered.first
  end

  # All capabilities across this framework's dimensions, in display order.
  def capabilities
    Capability.joins(:dimension)
              .where(dimensions: { framework_id: id })
              .merge(Dimension.order(:position))
              .order("dimensions.position", "capabilities.position")
  end
end

# One of the four maturity levels (1-4) for a capability, with a plain and an
# HTML-formatted description.
class CapabilityLevel < ApplicationRecord
  belongs_to :capability

  validates :value, presence: true, inclusion: { in: 1..4 },
                    uniqueness: { scope: :capability_id }
end

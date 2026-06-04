# A category within a framework (e.g. "Code", "SLOs & Error Budgets").
class Dimension < ApplicationRecord
  belongs_to :framework
  has_many :capabilities, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :framework_id }
end

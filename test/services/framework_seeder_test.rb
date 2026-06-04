require "test_helper"

class FrameworkSeederTest < ActiveSupport::TestCase
  test "seeds the Tech framework from the legacy YAML constants" do
    framework = FrameworkSeeder.seed_tech!

    assert_equal "tech", framework.slug
    assert_equal 5, framework.dimensions.count
    assert_equal %w[Code], framework.dimensions.order(:position).limit(1).pluck(:name)
    assert_equal 42, framework.capabilities.count
    assert_equal 168, CapabilityLevel.joins(capability: :dimension)
                                     .where(dimensions: { framework_id: framework.id }).count
  end

  test "maps min levels and level descriptions" do
    FrameworkSeeder.seed_tech!
    a3 = Capability.joins(:dimension)
                   .where(dimensions: { framework: Framework.find_by(slug: "tech") })
                   .find_by(slug: "a3")

    assert_equal "Test Suite", a3.name
    assert_equal 3, a3.min_level
    assert a3.level(3).description.present?
  end

  test "is idempotent (re-seeding does not duplicate)" do
    FrameworkSeeder.seed_tech!
    assert_no_difference ["Framework.count", "Dimension.count", "Capability.count", "CapabilityLevel.count"] do
      FrameworkSeeder.seed_tech!
    end
  end
end

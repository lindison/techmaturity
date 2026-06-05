require "test_helper"

class FrameworkSeederTest < ActiveSupport::TestCase
  test "seeds the Tech framework from the legacy YAML constants" do
    framework = FrameworkSeeder.seed_tech!

    assert_equal "tech", framework.slug
    assert_equal 5, framework.dimensions.count
    assert_equal %w[Code], framework.dimensions.order(:position).limit(1).pluck(:name)
    # 35 capabilities after trimming 7 that duplicate the SRE model (a4, a6, d3-d7).
    assert_equal 35, framework.capabilities.count
    assert_equal 140, CapabilityLevel.joins(capability: :dimension)
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

  test "re-seeding prunes capabilities no longer in the definition" do
    framework = FrameworkSeeder.seed_tech!
    dimension = framework.dimensions.find_by(slug: "a")
    ghost = dimension.capabilities.create!(name: "Ghost", slug: "a_ghost", position: 99)
    ghost.capability_levels.create!(value: 1, description: "x")
    assert Capability.exists?(ghost.id)

    FrameworkSeeder.seed_tech! # a_ghost is not in the YAML -> pruned (with its levels)

    refute Capability.exists?(ghost.id)
    refute CapabilityLevel.exists?(capability_id: ghost.id)
  end
end

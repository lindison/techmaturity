require "test_helper"

class AssessmentTest < ActiveSupport::TestCase
  setup do
    @framework = Framework.create!(name: "Demo", slug: "demo")
    @dim = @framework.dimensions.create!(name: "D", slug: "d", position: 0)
    @c1 = @dim.capabilities.create!(name: "C1", slug: "d1", position: 0, min_level: 3)
    @c2 = @dim.capabilities.create!(name: "C2", slug: "d2", position: 1, min_level: 3)
    @product = FactoryBot.create(:product)
    @assessment = @product.assessments.create!(framework: @framework)
  end

  test "value_for returns the response value for a capability" do
    @assessment.assessment_responses.create!(capability: @c1, value: 4)
    assert_equal 4, @assessment.reload.value_for(@c1)
    assert_nil @assessment.value_for(@c2)
  end

  test "dimension_average averages only answered capabilities" do
    @assessment.assessment_responses.create!(capability: @c1, value: 2)
    @assessment.assessment_responses.create!(capability: @c2, value: 4)
    assert_in_delta 3.0, @assessment.reload.dimension_average(@dim), 0.001
  end

  test "readiness is the share of target capabilities meeting min_level" do
    @assessment.assessment_responses.create!(capability: @c1, value: 3) # meets min 3
    @assessment.assessment_responses.create!(capability: @c2, value: 1) # below min 3
    assert_in_delta 50.0, @assessment.reload.readiness, 0.001
  end

  test "a capability cannot be answered twice in one assessment" do
    @assessment.assessment_responses.create!(capability: @c1, value: 2)
    dup = @assessment.assessment_responses.build(capability: @c1, value: 3)
    assert_not dup.valid?
  end
end

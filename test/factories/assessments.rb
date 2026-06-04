FactoryBot.define do
  factory :assessment do
    product
    framework { Framework.find_by(slug: "tech") || FrameworkSeeder.seed_tech! }
    latest { true }

    transient { fill { true } }

    after(:create) do |assessment, evaluator|
      if evaluator.fill
        assessment.framework.capabilities.each do |capability|
          assessment.assessment_responses.create!(capability: capability, value: rand(1..4))
        end
      end
    end
  end
end

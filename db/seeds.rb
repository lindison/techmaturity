# Seed the maturity framework *definitions* (dimensions, capabilities, levels).
# No demo applications/assessments are seeded — load those via mock_data tasks
# or the repo-assessment flow.
FrameworkSeeder.seed_all!
puts "Seeded frameworks: #{Framework.pluck(:slug).join(', ')}"

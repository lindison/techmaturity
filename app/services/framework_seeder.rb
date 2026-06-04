require "yaml"

# Seeds framework *definitions* (dimensions, capabilities, the four levels) into
# the normalized tables. Idempotent: matches on slug and updates in place, so
# re-seeding preserves IDs that assessments may reference.
class FrameworkSeeder
  CONSTANTS_DIR = Rails.root.join("app/assets/constants")

  def self.seed_all!
    seed_tech!
  end

  # The original Tech Maturity model, parsed from the legacy YAML constants.
  def self.seed_tech!
    plain     = load_yaml("capabilities.yaml")
    formatted = load_yaml("formatted_capabilities.yaml")

    seed!(
      slug: "tech",
      name: "Tech Maturity",
      description: "Code, Build & Test, Release, Operate, and Optimize.",
      position: 0,
      plain: plain,
      formatted: formatted
    )
  end

  # plain/formatted are the flat {"a"=>"Code","a1"=>"...","a1_1"=>"...","a1_min"=>3} hashes.
  def self.seed!(slug:, name:, description:, position:, plain:, formatted:)
    Framework.transaction do
      framework = Framework.find_or_initialize_by(slug: slug)
      framework.update!(name: name, description: description, position: position)

      dimension_keys(plain).each_with_index do |dkey, di|
        dimension = framework.dimensions.find_or_initialize_by(slug: dkey)
        dimension.update!(name: plain[dkey], position: di)

        capability_keys(plain, dkey).each_with_index do |ckey, ci|
          min = plain["#{ckey}_min"]
          capability = dimension.capabilities.find_or_initialize_by(slug: ckey)
          capability.update!(name: plain[ckey], position: ci, min_level: (min if min.is_a?(Integer)))

          (1..4).each do |value|
            level = capability.capability_levels.find_or_initialize_by(value: value)
            level.update!(
              description: plain["#{ckey}_#{value}"],
              formatted_description: formatted["#{ckey}_#{value}"] || plain["#{ckey}_#{value}"]
            )
          end
        end
      end
      framework
    end
  end

  def self.load_yaml(file)
    YAML.safe_load_file(CONSTANTS_DIR.join(file), aliases: true)
  end

  # Single-letter keys are dimensions ("a".."e").
  def self.dimension_keys(plain)
    plain.keys.select { |k| k.to_s.match?(/\A[a-z]\z/) }
  end

  # Keys like "a1","a2" under dimension "a" (excludes "a1_min", "a1_3", ...).
  def self.capability_keys(plain, dkey)
    plain.keys.select { |k| k.to_s.match?(/\A#{dkey}\d+\z/) }.sort_by { |k| k.to_s[/\d+/].to_i }
  end

  private_class_method :seed!, :load_yaml, :dimension_keys, :capability_keys
end

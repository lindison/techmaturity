require "yaml"

# Seeds framework *definitions* (dimensions, capabilities, the four levels) into
# the normalized tables. Idempotent: matches on slug and updates in place, so
# re-seeding preserves IDs that assessments may reference.
class FrameworkSeeder
  CONSTANTS_DIR = Rails.root.join("app/assets/constants")

  def self.seed_all!
    seed_tech!
    seed_sre!
  end

  # SRE Maturity, defined in db/frameworks/sre.yml (nested format).
  def self.seed_sre!
    seed_definition!(YAML.safe_load_file(Rails.root.join("db/frameworks/sre.yml")))
  end

  # Seeds a framework from a nested definition:
  #   { "slug","name","description","position",
  #     "dimensions" => [ { "slug","name",
  #       "capabilities" => [ { "slug","name","min_level","levels" => [l1,l2,l3,l4] } ] } ] }
  def self.seed_definition!(definition)
    Framework.transaction do
      framework = Framework.find_or_initialize_by(slug: definition["slug"])
      framework.update!(name: definition["name"], description: definition["description"],
                        position: definition["position"] || 0)

      dim_slugs = []
      cap_slugs = []
      definition.fetch("dimensions").each_with_index do |dim_def, di|
        dimension = framework.dimensions.find_or_initialize_by(slug: dim_def["slug"])
        dimension.update!(name: dim_def["name"], position: di)
        dim_slugs << dim_def["slug"]

        dim_def.fetch("capabilities").each_with_index do |cap_def, ci|
          capability = dimension.capabilities.find_or_initialize_by(slug: cap_def["slug"])
          capability.update!(name: cap_def["name"], position: ci, min_level: cap_def["min_level"])
          cap_slugs << cap_def["slug"]

          Array(cap_def["levels"]).each_with_index do |description, li|
            level = capability.capability_levels.find_or_initialize_by(value: li + 1)
            level.update!(description: description, formatted_description: description)
          end
        end
      end
      prune_orphans!(framework, dim_slugs, cap_slugs)
      framework
    end
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

      dim_slugs = []
      cap_slugs = []
      dimension_keys(plain).each_with_index do |dkey, di|
        dimension = framework.dimensions.find_or_initialize_by(slug: dkey)
        dimension.update!(name: plain[dkey], position: di)
        dim_slugs << dkey

        capability_keys(plain, dkey).each_with_index do |ckey, ci|
          min = plain["#{ckey}_min"]
          capability = dimension.capabilities.find_or_initialize_by(slug: ckey)
          capability.update!(name: plain[ckey], position: ci, min_level: (min if min.is_a?(Integer)))
          cap_slugs << ckey

          (1..4).each do |value|
            level = capability.capability_levels.find_or_initialize_by(value: value)
            level.update!(
              description: plain["#{ckey}_#{value}"],
              formatted_description: formatted["#{ckey}_#{value}"] || plain["#{ckey}_#{value}"]
            )
          end
        end
      end
      prune_orphans!(framework, dim_slugs, cap_slugs)
      framework
    end
  end

  # Remove capabilities/dimensions that are no longer in the definition (e.g. when
  # a capability is dropped from the YAML), along with their levels and any
  # assessment responses (cascade via dependent: :destroy). Keeps the DB an exact
  # mirror of the source-of-truth files, so a re-seed reconciles trims cleanly.
  def self.prune_orphans!(framework, dimension_slugs, capability_slugs)
    Capability.joins(:dimension)
              .where(dimensions: { framework_id: framework.id })
              .where.not(slug: capability_slugs)
              .destroy_all
    framework.dimensions.where.not(slug: dimension_slugs).destroy_all
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

# Populates / clears demo data: ~40 made-up applications themed around
# Infoblox DDI (DNS, DHCP, IPAM) and network-security services. Used by the
# mock_data:infoblox rake task and the reset/data admin page.
class SampleDataService
  # name, product_type, and a few searchable service tags.
  INFOBLOX_APPS = [
    ["NIOS Grid Manager",            "Product",       %w[ddi platform on-prem]],
    ["BloxOne DDI",                  "Product",       %w[ddi cloud saas]],
    ["BloxOne Threat Defense",       "Product",       %w[security cloud saas]],
    ["DNS Firewall",                 "Component",     %w[dns security]],
    ["DHCP Failover Service",        "Component",     %w[dhcp high-availability]],
    ["IPAM Core",                    "Product",       %w[ipam platform]],
    ["Grid Sync Engine",             "Sub component", %w[ddi replication]],
    ["Cloud Network Automation",     "Product",       %w[cloud automation]],
    ["DNS Traffic Control",          "Component",     %w[dns load-balancing]],
    ["Reporting and Analytics",      "Product",       %w[reporting analytics]],
    ["DNS Cache Acceleration",       "Sub component", %w[dns performance]],
    ["Anycast DNS",                  "Component",     %w[dns anycast]],
    ["DNS over HTTPS Gateway",       "Component",     %w[dns security doh]],
    ["Subscriber Services",          "Product",       %w[dhcp subscriber]],
    ["Network Insight",              "Product",       %w[discovery visibility]],
    ["Threat Intelligence Feed",     "Component",     %w[security threat-intel]],
    ["DNSSEC Manager",               "Component",     %w[dns security dnssec]],
    ["DHCP Fingerprinting",          "Sub component", %w[dhcp security]],
    ["IPv6 Migration Service",       "Component",     %w[ipam ipv6]],
    ["Grid Backup and Restore",      "Sub component", %w[platform backup]],
    ["Outbound API Integration",     "Component",     %w[api automation]],
    ["Microsoft Management Service", "Component",     %w[integration microsoft]],
    ["Cloud Platform Appliance",     "Product",       %w[cloud platform]],
    ["DTC Health Monitor",           "Sub component", %w[dns monitoring]],
    ["Response Policy Zones",        "Component",     %w[dns security rpz]],
    ["Data Connector",               "Component",     %w[integration data]],
    ["Dossier Threat Lookup",        "Component",     %w[security threat-intel]],
    ["TIDE Threat Exchange",         "Product",       %w[security threat-intel]],
    ["ActiveTrust Cloud",            "Product",       %w[security cloud]],
    ["BloxOne Endpoint",             "Component",     %w[security endpoint]],
    ["DNS Forwarding Proxy",         "Sub component", %w[dns proxy]],
    ["Grid License Manager",         "Sub component", %w[platform licensing]],
    ["Discovery and Visibility",     "Product",       %w[discovery network]],
    ["Smart Folders Service",        "Sub component", %w[platform organization]],
    ["Extensible Attributes Engine", "Sub component", %w[platform metadata]],
    ["Reporting Server",             "Component",     %w[reporting analytics]],
    ["NTP Sync Service",             "Sub component", %w[platform time]],
    ["Captive Portal",               "Component",     %w[dhcp portal]],
    ["RADIUS Authentication",        "Component",     %w[security authentication]],
    ["Syslog Aggregator",            "Sub component", %w[platform logging]]
  ].freeze

  CAPABILITY_KEYS = (
    (1..12).map { |i| "a#{i}" } + (1..8).map { |i| "b#{i}" } +
    (1..10).map { |i| "c#{i}" } + (1..8).map { |i| "d#{i}" } +
    (1..4).map  { |i| "e#{i}" }
  ).freeze

  # Creates any apps that don't already exist, each with a random latest score
  # and its service tags. Returns the number of apps created.
  def self.load_infoblox!
    INFOBLOX_APPS.count do |name, product_type, tags|
      next false if Product.unscoped.exists?(name: name)

      # Create unassessed: the first score's callback assesses the product.
      product = Product.create!(name: name, product_type: product_type)
      tags.each { |value| product.tags.create!(key: "service", value: value) }
      product.scores.create!(CAPABILITY_KEYS.index_with { rand(1..4) })
      true
    end
  end

  # Removes every product (and, via dependent: :destroy, its scores and tags).
  # unscoped so inactive products are cleared too.
  def self.clear!
    Product.unscoped.destroy_all
  end
end

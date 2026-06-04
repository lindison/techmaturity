# A background repository assessment for a product. Holds the running status,
# progress (0-100), and — once complete — the detected capability levels and a
# per-framework findings summary in `result`. The score form polls it and, when
# complete, pre-fills from `result["prefill"]`.
class RepoScan < ApplicationRecord
  belongs_to :product

  STATUSES = %w[pending running complete error].freeze

  # A scan that hasn't progressed in this long is treated as dead (e.g. the
  # process restarted mid-run) and a fresh one is started in its place.
  STALE_AFTER = 15.minutes

  scope :recent, -> { order(created_at: :desc) }

  def in_progress?
    %w[pending running].include?(status)
  end

  def complete?
    status == "complete"
  end

  def failed?
    status == "error"
  end

  def stale?
    in_progress? && updated_at < STALE_AFTER.ago
  end

  # capability_id => level (1-4), from the completed scan.
  def prefill
    result.fetch("prefill", {}).transform_keys(&:to_i)
  end

  # [{ "name", "slug", "findings" => [{ "title", "level", "note" }] }, ...]
  def models
    result.fetch("models", [])
  end

  def source
    result["source"].presence || repo
  end
end

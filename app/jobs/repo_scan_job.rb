# Runs a repository assessment (file detectors + chunked LLM analysis) for every
# maturity model, in the background, updating the RepoScan's progress as it goes.
# The chunked AI pass takes minutes, so this can't run inside a web request.
class RepoScanJob < ApplicationJob
  queue_as :default

  def perform(scan_id)
    scan = RepoScan.find_by(id: scan_id)
    return unless scan&.in_progress?

    scan.update!(status: "running", progress: 1)
    frameworks = Framework.ordered.to_a
    prefill = {}
    models = []
    source = nil

    frameworks.each_with_index do |framework, index|
      # Map the framework's internal chunk progress onto an overall 0-99%.
      on_progress = lambda do |done, total|
        fraction = total.to_i.zero? ? 0.0 : done.to_f / total
        overall = (((index + fraction) / frameworks.size) * 100).round
        scan.update_column(:progress, overall.clamp(1, 99))
      end

      result = RepoAssessmentService.assess(scan.repo, framework: framework.slug, progress: on_progress)
      if result.error
        scan.update!(status: "error", error: result.error)
        return
      end

      source ||= result.source
      by_slug = framework.capabilities.index_by(&:slug)
      result.scores.each do |slug, level|
        capability = by_slug[slug]
        prefill[capability.id.to_s] = level if capability
      end
      models << {
        "name" => framework.name, "slug" => framework.slug,
        "findings" => result.findings.map { |f| { "title" => f.title, "level" => f.level, "note" => f.note } }
      }
    end

    scan.update!(status: "complete", progress: 100,
                 result: { "prefill" => prefill, "models" => models, "source" => source })
  rescue => e
    Rails.logger.error("RepoScanJob #{scan_id} failed: #{e.class}: #{e.message}")
    scan&.update(status: "error", error: "Assessment failed: #{e.message}")
  end
end

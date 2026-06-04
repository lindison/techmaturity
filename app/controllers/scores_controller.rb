
# Manages assessments (still surfaced under the "scores" routes/UI term).
# A "score" run assesses a product against EVERY maturity model in one process:
# the form spans all frameworks' dimensions, and a submit creates one Assessment
# per framework that received answers — so an asset carries a Tech score and an
# SRE score (and any future model) produced together, not one-at-a-time.
class ScoresController < ApplicationController
  before_action :set_product
  before_action :set_assessment, only: [:show]

  # GET /products/:id/scores
  def index
    @frameworks = Framework.ordered.to_a
    @assessments_by_framework = @frameworks.index_with do |framework|
      @product.assessments.where(framework: framework).order(:created_at).to_a
    end
  end

  # GET /products/:id/scores/:id
  def show
    @framework = @assessment.framework
  end

  # GET /products/:id/scores/new
  def new
    @frameworks = Framework.ordered.to_a
    @prefill = {} # capability_id => level (1-4)
    prefill_from_last_assessments

    if params[:repo].present? && CONFIGS[:enable_repo_assessment]
      @scan = find_or_start_scan(params[:repo])
      @prefill.merge!(@scan.prefill) if @scan.complete?
    end
  end

  # GET /products/:id/scores/scan_status?id=
  # Polled by the scanning page until the background assessment finishes.
  def scan_status
    scan = @product.repo_scans.find(params[:id])
    render json: { status: scan.status, progress: scan.progress, error: scan.error }
  end

  # POST /products/:id/scores
  def create
    responses = (response_params[:responses] || {}).to_h
    @saved = save_assessments(responses, response_params[:comment])

    if @product.is_assessable? && @saved.any?
      @product.update(is_assessed: true)
      models = @saved.size
      redirect_to @product, notice: { type: 'success',
                                      message: "Assessment saved across #{models} maturity model#{'s' unless models == 1}." }
    else
      @frameworks = Framework.ordered.to_a
      @prefill = responses.reject { |_id, v| v.blank? }.to_h { |id, v| [id.to_i, v.to_i] }
      flash.now[:notice] = { type: 'danger', message: 'Pick at least one level, then Save.' }
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end

  def set_assessment
    @assessment = @product.assessments.find(params[:id])
  end

  def response_params
    params.fetch(:score, {}).permit(:comment, responses: {})
  end

  # responses is { "<capability_id>" => "<level 1-4>" } spanning all frameworks.
  # Each answered capability is routed to its own framework, and one Assessment
  # is saved per framework that got at least one answer.
  def save_assessments(responses, comment)
    answered = responses.reject { |_id, value| value.blank? }
    return [] if answered.empty?

    capabilities = Capability.where(id: answered.keys.map(&:to_i))
                             .includes(dimension: :framework).index_by(&:id)
    by_framework = answered.group_by { |id, _value| capabilities[id.to_i]&.dimension&.framework }.except(nil)

    by_framework.filter_map do |framework, pairs|
      assessment = @product.assessments.new(framework: framework, comment: comment)
      pairs.each { |id, value| assessment.assessment_responses.build(capability: capabilities[id.to_i], value: value.to_i) }
      next unless assessment.save

      assessment.make_latest!
      assessment
    end
  end

  # "Re-Evaluate" starts from each framework's previous answers.
  def prefill_from_last_assessments
    @frameworks.each do |framework|
      last = @product.assessments.where(framework: framework).order(:created_at).last
      next unless last

      last.assessment_responses.each { |response| @prefill[response.capability_id] = response.value }
    end
  end

  # The repo assessment (file detectors + minutes-long chunked LLM analysis,
  # across every framework) runs in a background job. Reuse the latest scan for
  # this repo — whether complete, failed, or still running — so reloads show its
  # result instead of restarting; only start fresh if there is none, it's stale
  # (a dead in-flight run), or the user explicitly asked to re-scan.
  def find_or_start_scan(repo)
    unless params[:rescan]
      scan = @product.repo_scans.where(repo: repo).recent.first
      return scan if scan && !scan.stale?
    end

    scan = @product.repo_scans.create!(repo: repo, status: "pending", progress: 0)
    RepoScanJob.perform_later(scan.id)
    scan
  end
end

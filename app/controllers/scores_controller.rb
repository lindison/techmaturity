
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
    apply_repo_assessment(params[:repo]) if params[:repo].present? && CONFIGS[:enable_repo_assessment]
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

  # Scan/clone the repo once per framework (each scores against its own rubric)
  # and merge detected levels into @prefill, keyed by capability id.
  def apply_repo_assessment(location)
    results = @frameworks.map { |framework| [framework, RepoAssessmentService.assess(location, framework: framework.slug)] }
    @repo_assessments = results.reject { |_framework, result| result.error }
    @repo_error = results.filter_map { |_framework, result| result.error }.first if @repo_assessments.empty?
    @repo_source = @repo_assessments.first&.last&.source

    @repo_assessments.each do |framework, result|
      by_slug = framework.capabilities.index_by(&:slug)
      result.scores.each do |slug, level|
        capability = by_slug[slug]
        @prefill[capability.id] = level if capability
      end
    end
  end
end

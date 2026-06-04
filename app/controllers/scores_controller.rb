
# Manages assessments (still surfaced under the "scores" routes/UI term).
# Each saved "score" is an Assessment of a product against its framework, with
# one response per capability.
class ScoresController < ApplicationController
  before_action :set_product
  before_action :set_assessment, only: [:show]

  # GET /products/:id/scores
  def index
    @framework = @product.framework_or_default
    @assessments = @product.assessments.where(framework: @framework).order(:created_at)
  end

  # GET /products/:id/scores/:id
  def show
    @framework = @assessment.framework
  end

  # GET /products/:id/scores/new
  def new
    @framework = @product.framework_or_default
    @assessment = @product.assessments.new(framework: @framework)
    prefill_from_last_assessment
    apply_repo_assessment(params[:repo]) if params[:repo].present? && CONFIGS[:enable_repo_assessment]
  end

  # POST /products/:id/scores
  def create
    @framework = @product.framework_or_default
    @assessment = @product.assessments.new(framework: @framework, comment: response_params[:comment])
    build_responses(response_params[:responses])

    if @product.is_assessable? && @assessment.save
      @assessment.make_latest!
      @product.update(is_assessed: true)
      redirect_to @product, notice: { type: 'success', message: 'Assessment was successfully saved.' }
    else
      flash.now[:notice] = { type: 'danger', message: 'Assessment failed to save.' }
      render :new
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

  # responses is { "<capability_id>" => "<level 1-4>" }. Only capabilities
  # belonging to this product's framework are accepted.
  def build_responses(responses)
    return if responses.blank?

    allowed = @framework.capabilities.index_by(&:id)
    responses.each do |capability_id, value|
      next if value.blank?

      capability = allowed[capability_id.to_i]
      @assessment.assessment_responses.build(capability: capability, value: value.to_i) if capability
    end
  end

  # "Re-Evaluate" starts from the previous assessment's answers.
  def prefill_from_last_assessment
    last = @product.assessments.where(framework: @framework).order(:created_at).last
    return unless last

    last.assessment_responses.each do |response|
      @assessment.assessment_responses.build(capability_id: response.capability_id, value: response.value)
    end
  end

  # Pre-fill detected capability levels from a repository scan (slug -> level).
  def apply_repo_assessment(location)
    @repo_assessment = RepoAssessmentService.assess(location, framework: @framework.slug)
    return if @repo_assessment.error

    by_slug = @framework.capabilities.index_by(&:slug)
    @repo_assessment.scores.each do |slug, level|
      capability = by_slug[slug]
      next unless capability

      response = @assessment.assessment_responses.detect { |r| r.capability_id == capability.id }
      response ? response.value = level : @assessment.assessment_responses.build(capability: capability, value: level)
    end
    @assessment.comment = "Auto-assessed from #{@repo_assessment.source}\n" +
                          @repo_assessment.findings.map { |f| "#{f.title} (#{f.key.upcase}) = Level #{f.level} — #{f.note}" }.join("\n")
  end
end

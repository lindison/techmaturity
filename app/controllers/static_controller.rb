
# Static controller is only for pages that are not
# associated with any resources
class StaticController < ApplicationController
  before_action :require_data_management, only: %i[data load_sample reset_database]

  def dashboard
    @frameworks = Framework.ordered
    @framework = Framework.find_by(slug: params[:framework]) || Framework.default
    @products_count = Product.count
    @has_data = @framework.present? && @framework.assessments.latest.exists?

    return unless @has_data

    @capability_labels = @framework.capabilities.map(&:name)
    @org_capability_values = Assessment.org_capability_values(@framework)
    @org_expanded_values = Assessment.org_expanded_dimension_values(@framework)
    @org_readiness = Assessment.org_readiness(@framework)
  end

  def docs; end

  def about; end

  def contact; end

  def send_to_slack
    NotifySlackService.build.call(name: params[:name], email: params[:email], message: params[:message])
    flash[:notice] = { type: 'success', message: 'Thanks for your valuable feedback.' }
    redirect_to controller: 'products', action: 'index'
  end

  # Demo data management page (load sample data + PIN-gated reset).
  def data
    @product_count = Product.unscoped.count
  end

  def load_sample
    created = SampleDataService.load_infoblox!
    flash[:notice] = { type: 'success', message: "Loaded #{created} Infoblox demo application(s)." }
    redirect_to data_path
  end

  def reset_database
    if params[:pin].to_s == reset_pin
      SampleDataService.clear!
      flash[:notice] = { type: 'success', message: 'Database cleared.' }
    else
      flash[:notice] = { type: 'danger', message: 'Incorrect PIN — database was not cleared.' }
    end
    redirect_to data_path
  end

  private

  # The data page can load demo data and (PIN-gated) wipe the database, so it is
  # only exposed where explicitly enabled (off in production by default).
  def require_data_management
    head :not_found unless CONFIGS[:enable_data_management]
  end

  # Overridable via env; defaults to the agreed demo PIN.
  def reset_pin
    ENV.fetch('RESET_PIN', '8805')
  end
end

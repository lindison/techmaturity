
# Static controller is only for pages that are not
# associated with any resources
class StaticController < ApplicationController
  def dashboard
    # Score.summary always returns one (all-NULL) row, so guard on real data.
    @summary = Score.where(latest: true).exists? ? Score.summary[0] : nil
    @products_count = Product.count
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

  # Overridable via env; defaults to the agreed demo PIN.
  def reset_pin
    ENV.fetch('RESET_PIN', '8805')
  end
end

Rails.application.routes.draw do

  # Static Routes 
  root :to => 'static#dashboard'
  get '/docs' => 'static#docs'
  get '/about' => 'static#about'
  get '/contact' => 'static#contact'
  post '/feedback' => 'static#send_to_slack'

  # Demo data management: load sample data + PIN-gated database reset
  get  '/data' => 'static#data', as: :data
  post '/data/load_sample' => 'static#load_sample', as: :load_sample
  post '/data/reset' => 'static#reset_database', as: :reset_data

  # Dump Endpoint
  get 'dump' => 'dump#dump'

  # External Endpoints
  get '/github', to: redirect('https://github.com/lindison/techmaturity')

  # Restful resources
  resources :products do
    resources :scores, except: [:destroy, :update, :edit] do
      get :scan_status, on: :collection
    end
    resources :tags, except: [:index, :show]
  end

end

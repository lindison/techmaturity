source 'https://rubygems.org'

ruby '3.3.6'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.2.0'
gem 'pg', '~> 1.5'
# Use Puma as the app server
gem 'puma', '~> 6.4'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 6.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '4.1.8'

# Hotwire front-end: ESM via importmaps, Turbo for navigation, Stimulus for
# behavior. (Replaces the inert Turbolinks and the Sprockets JS bundle.)
gem 'importmap-rails', '~> 2.1'
gem 'turbo-rails', '~> 2.0'
gem 'stimulus-rails', '~> 1.3'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.11'
# Will Paginate gem is used for pagination of the assets index page
gem 'will_paginate', '~> 3.3'
# Faker gem is used to generate mock data for testing
gem 'faker', '~> 3.2'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger
  #     console
  gem 'byebug', platform: :mri
  gem 'factory_bot_rails'
  gem 'rubocop', require: false
end

group :development do
  gem 'listen', '~> 3.7'
  # Spring speeds up development by keeping your application running in the
  #     background. Read more: https://github.com/rails/spring
  gem 'spring', '~> 4.1'
  gem 'spring-watcher-listen', '~> 2.1'
end

group :test do
  # Rails 6.1's test runner is incompatible with minitest 6's `run` signature.
  gem 'minitest', '~> 5.25'
  gem 'simplecov', require: false
  # System tests: drive a real headless Chromium (Capybara + Cuprite/CDP) so
  # the JS-heavy dashboard charts and live search are covered.
  gem 'capybara', '~> 3.40'
  gem 'cuprite', '~> 0.15'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem

gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

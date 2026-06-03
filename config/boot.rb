ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# Rails < 7.1 references Logger before requiring it; newer concurrent-ruby no
# longer pulls it in transitively. Require it explicitly so boot doesn't fail.
require 'logger'

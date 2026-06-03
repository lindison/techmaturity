#!/bin/sh
set -e

# Spring is a dev convenience and only gets in the way of the server process.
export DISABLE_SPRING=1

# Rails 7.2+ requires a String secret_key_base in every environment. Generate
# one if the orchestrator didn't provide it (note: a generated secret changes
# on every boot, so set SECRET_KEY_BASE in the environment for stable sessions).
# `rails secret` replaces the `rake secret` task that was removed in Rails 7.2.
export SECRET_KEY_BASE="${SECRET_KEY_BASE:-$(bin/rails secret)}"

# Create (if needed), migrate, and seed the database.
bin/rails db:prepare

exec bin/rails server -b 0.0.0.0 -p 3000

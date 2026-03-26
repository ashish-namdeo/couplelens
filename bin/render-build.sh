#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
yarn install
SECRET_KEY_BASE_DUMMY=1 bundle exec rake assets:precompile
SECRET_KEY_BASE_DUMMY=1 bundle exec rake assets:clean
bundle exec rake db:migrate

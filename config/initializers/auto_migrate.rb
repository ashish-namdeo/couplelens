# frozen_string_literal: true

# This initializer forces Rails to automatically run pending database migrations
# and seeds when the Puma server starts up in production.
# This is a workaround for Render's Free Tier since the built-in Shell is locked.

if Rails.env.production?
  Rails.logger.info "Starting automatic database migrations..."
  
  # Run the migrations synchronously so the app doesn't accept requests until the DB is ready
  system('bundle exec rake db:migrate')
  
  Rails.logger.info "Finished automatic database migrations."
end

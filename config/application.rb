require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Wander
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Secrets come from the environment: SECRET_KEY_BASE (required; Rails 8.1
    # resolves ENV["SECRET_KEY_BASE"] before consulting credentials). This repo
    # is public, so config/credentials.yml.enc is never committed — Rails'
    # conventional encrypted credentials still work as an escape hatch but are
    # not required to boot. See docs/adr/20260823-secrets-from-env.md.

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # The whole app works in one time zone, taken from the TZ env var (UTC by
    # default). Segment times are stored as absolute UTC instants; the
    # human-facing "8:00 PM MDT" wording a booking used is preserved verbatim in
    # a companion *_label column — see docs/adr/20260823-store-instant-and-label.md.
    config.time_zone = ENV.fetch("TZ", "UTC")

    # The running build's git SHA — written into REVISION/REVISION_SHORT by the
    # Docker build (absent in dev, so it falls back to "dev"). Shown in the
    # footer so you can tell which build is live.
    revision       = Rails.root.join("REVISION")
    revision_short = Rails.root.join("REVISION_SHORT")
    config.x.git_sha       = revision.exist?       ? revision.read.strip       : "dev"
    config.x.git_sha_short = revision_short.exist? ? revision_short.read.strip : "dev"
  end
end

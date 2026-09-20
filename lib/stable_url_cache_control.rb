# Files under public/ all get one far-future Cache-Control, which is what the
# digest-stamped assets want. These few live at stable URLs instead, so a client
# holding a year-old copy would never ask for the replacement — the service
# worker most of all, since a stale one keeps serving its own stale cache.
class StableUrlCacheControl
  PATHS = %w[/service-worker.js /manifest.webmanifest].freeze
  REVALIDATE = "public, max-age=0, must-revalidate".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    headers["cache-control"] = REVALIDATE if PATHS.include?(env["PATH_INFO"])
    [ status, headers, body ]
  end
end

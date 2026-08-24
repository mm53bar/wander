class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import
  # maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses.
  stale_when_importmap_changes

  # CSRF tokens are session-scoped and browser-only; JSON API clients (a mail
  # ingestion script, say) have no session to carry one in, and there is no auth
  # to protect here anyway — see docs/adr/20260823-no-auth-needed.md. A JSON
  # *body* counts as well as a `.json` path, so a bare `POST /trips/:id/segments`
  # with `Content-Type: application/json` isn't treated as a forgery-prone form.
  protect_from_forgery with: :exception, unless: -> { json_request? }

  private

  def json_request?
    request.format.json? || request.media_type&.include?("json")
  end
end

Rails.application.routes.draw do
  # Health check for load balancers / uptime monitors — 200 if the app booted.
  get "up" => "rails/health#show", as: :rails_health_check

  root "trips#index"

  resources :trips do
    member do
      post :archive
      post :unarchive
    end
    resources :segments, only: [ :new, :create ]
    resources :raw_emails, only: [ :index, :create ]
  end

  resources :segments, only: [ :edit, :update, :destroy ] do
    # One QR image per segment (a booking pass, boarding QR, etc.).
    resource :qr_code, only: [ :create, :destroy ]
    # Repoint a segment to a different trip, or split it into a new one.
    member do
      get :move
      patch :relocate
      post :split
    end
  end

  # wander's own inbox of travel-related mail captured from the shared casey@
  # mailbox by EmailIntakeJob. File onto a trip or dismiss as a false positive.
  resources :inbound_emails, only: [ :index, :destroy ] do
    member do
      post :file
      post :accept
      post :ignore
      post :undo
    end
  end

  # Settings — the managed list of travel-provider senders the classifier trusts.
  resources :safe_senders, only: [ :index, :create, :update, :destroy ]
  # Addresses wander will reply to about a booking it couldn't process.
  resources :allowed_senders, only: [ :create, :update, :destroy ]
  get "settings", to: "safe_senders#index", as: :settings

  # Draft an itinerary segment from a stored source email via the LLM.
  get "raw_emails/:id/draft_segment", to: "segments#draft_from_email", as: :draft_segment

  # Subscribable iCalendar feed of every timed segment. The format default means
  # url_for omits the extension, so anything building a subscribe URL has to
  # append ".ics" itself — calendar clients sniff on it.
  get "calendar", to: "calendars#show", as: :calendar, defaults: { format: "ics" }
end

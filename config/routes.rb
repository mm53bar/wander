Rails.application.routes.draw do
  # Health check for load balancers / uptime monitors — 200 if the app booted.
  get "up" => "rails/health#show", as: :rails_health_check

  root "trips#index"

  resources :trips do
    resources :segments, only: [ :new, :create ]
    resources :raw_emails, only: [ :index, :create ]
  end

  resources :segments, only: [ :edit, :update, :destroy ] do
    # One QR image per segment (a booking pass, boarding QR, etc.).
    resource :qr_code, only: [ :create, :destroy ]
  end

  # wander's own inbox of travel-related mail captured from the shared casey@
  # mailbox by EmailIntakeJob. File onto a trip or dismiss as a false positive.
  resources :inbound_emails, only: [ :index ] do
    member do
      post :file
      post :ignore
    end
  end

  # Subscribable iCalendar feed of every timed segment. calendar_path(format: :ics)
  # renders /calendar.ics; the bare /calendar redirects to it.
  get "calendar", to: "calendars#show", as: :calendar, defaults: { format: "ics" }
end

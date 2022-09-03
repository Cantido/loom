defmodule LoomWeb.Router do
  use LoomWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LoomWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LoomWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/api", LoomWeb do
    pipe_through :api

    get "/events/:source/:id", EventController, :show
    get "/events", EventController, :stream
    post "/events", EventController, :create

    get "/streams", StreamController, :index

    resources "/subscriptions", SubscriptionController, except: [:new, :edit]

    resources "/webhooks", WebhookController, except: [:new, :edit] do
      get "/confirm", WebhookController, :confirm, as: :confirm
      post "/confirm", WebhookController, :confirm, as: :confirm
    end
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LoomWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

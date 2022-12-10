defmodule LoomWeb.Router do
  use LoomWeb, :router

  import LoomWeb.UserAuth

  require Logger

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LoomWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_token_auth do
    plug LoomWeb.TokenBearerAuthPipeline
    plug :load_team
  end

  defp load_team(conn, _) do
    assign(conn, :current_team, Guardian.Plug.current_resource(conn).team)
  end

  scope "/", LoomWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/adapters/aws", LoomWeb do
    pipe_through :api

    post "/s3", AwsS3EventController, :create
  end

  scope "/auth", LoomWeb do
    post "/tokens", OauthController, :grant
  end

  scope "/api", LoomWeb do
    pipe_through [:api, :require_token_auth]

    post "/events", EventController, :create

    resources "/sources", SourceController do
      resources "/events", EventController
    end

    resources "/subscriptions", SubscriptionController, except: [:new, :edit]

    resources "/webhooks", WebhookController, except: [:new, :edit] do
      get "/confirm", WebhookController, :confirm, as: :confirm
      post "/confirm", WebhookController, :confirm, as: :confirm
    end
  end

  scope "/", LoomWeb do
    pipe_through [:browser, :require_authenticated_user]

    resources "/teams", TeamController do
      resources "/members", MemberController
      resources "/sources", SourceController
      resources "/tokens", TokenController
    end
  end

  scope "/", LoomWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", LoomWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", LoomWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
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

defmodule LoomWeb.Router do
  use LoomWeb, :router

  alias Loom.Accounts.Token

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LoomWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :auth
    plug :accepts, ["json"]
  end

  defp auth(conn, _opts) do
    with {user, pass} <- Plug.BasicAuth.parse_basic_auth(conn),
         {:ok, %Token{} = token} <- Loom.Accounts.verify_token(user, pass) do
      assign(conn, :current_account, token.account)
    else
      _ -> conn |> Plug.BasicAuth.request_basic_auth() |> halt()
    end
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

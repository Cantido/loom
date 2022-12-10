defmodule LoomWeb.TokenBearerAuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :loom,
    module: LoomWeb.Tokens,
    error_handler: LoomWeb.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end

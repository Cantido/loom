defmodule LoomWeb.TokenBearerAuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :loom,
    module: LoomWeb.Tokens,
    error_handler: LoomWeb.AuthErrorHandler,
    key: :current_token

  plug Guardian.Plug.VerifyHeader
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end

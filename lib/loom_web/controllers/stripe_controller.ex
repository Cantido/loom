defmodule LoomWeb.StripeController do
  use LoomWeb, :controller
  alias Loom.Billing

  def event(conn, params) do
    case Billing.handle_stripe_event(params) do
      :ok ->
        resp(conn, 200, "")
      {:errror, reason} ->
        Logger.error("Unable to handle Stripe event ID #{params["id"]}, reason: #{inspect reason}")
        resp(conn, 500, "")
    end
  end
end

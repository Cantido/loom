defmodule Loom.Billing do
  alias Loom.Billing.UsageWorker
  alias Loom.Accounts.Team

  def report_usage_multi(event) do
    UsageWorker.new(%{"sub_id" => "si_MyBjIIPGvGSVlY", "timestamp" => DateTime.to_iso8601(event.inserted_at)})
  end

  def create_payment_link(%Team{} = team) do
    Stripe.PaymentLink.create(%{
      line_items: [
        %{
          price: Application.fetch_env!(:loom, :tier_one_price_id),
          quantity: 1
         }
      ],
      metadata: %{
        team_id: team.id
      }
    })
  end

  def handle_stripe_event(%{"type" => "checkout.session.completed"} = event) do
    checkout_session = event["data"]["object"]

    {:ok, _team} =
      Loom.Accounts.get_team!(checkout_session["metadata"]["team_id"])
      |> Loom.Accounts.update_team(%{stripe_subscription_id: checkout_session["subscription"]})

    :ok
  end

  def handle_stripe_event(_), do: :ok
end

defmodule Loom.Billing.SourceUsageReporter do
  use Oban.Worker
  import Ecto.Query

  alias Loom.Repo
  alias Loom.Accounts.Team
  alias Stripe.SubscriptionItem.Usage

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    team_query =
      from t in Team,
      where: t.id == ^args[:team_id],
      preload: [:sources]

    team = Repo.one!(team_query)

    source_count = Enum.count(team.sources)
    {:ok, _} = Usage.create(team.stripe_subcription_item_id, %{quantity: source_count, timestamp: DateTime.to_unix(DateTime.utc_now())})

    :ok
  end
end

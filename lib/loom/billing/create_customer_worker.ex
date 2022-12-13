defmodule Loom.Billing.CreateCustomerWorker do
  use Oban.Worker

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    user = Loom.Accounts.get_user!(args["user_id"])

    {:ok, customer} = Stripe.Customer.create(%{email: user.email})

    {:ok, _user} = Loom.Accounts.apply_user_customer_id(user, %{stripe_customer_id: customer.id})

    :ok
  end
end

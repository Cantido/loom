defmodule Loom.Accounts.Account do
  use Loom.Schema

  alias Loom.Source
  alias Loom.Subscriptions.Webhook

  schema "accounts" do
    has_many :sources, Source
    has_many :webhooks, Webhook
  end
end

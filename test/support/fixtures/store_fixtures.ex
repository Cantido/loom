defmodule Loom.StoreFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loom.Store` context.
  """

  import Loom.AccountsFixtures

  @doc """
  Generate a source.
  """
  def source_fixture(attrs \\ %{}) do
    {:ok, source} =
      Loom.Store.create_source(
        Map.get(attrs, :account, account_fixture()),
        Map.get(attrs, :source, "loom-test-fixture")
      )

    source
  end
end

defmodule Loom.EventTest do
  use Loom.DataCase, async: true
  doctest Loom.Event

  test "changeset returns OK when only required fields are given" do
    cs =
      Loom.Event.changeset(
        %Loom.Event{},
        %{
          id: "6e8bc430-9c3a-11d9-9669-0800200c9a66",
          source: "https://github.com/cloudevents",
          type: "com.example.object.deleted.v2"
        }
      )

    assert cs.valid?
  end
end

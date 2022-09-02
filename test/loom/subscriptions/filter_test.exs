defmodule Loom.Subscriptions.FilterTest do
  use ExUnit.Case, async: true

  alias Loom.Subscriptions.Filter

  doctest Filter

  describe "matches_event/2" do
    test "returns true for an exact match with all params present" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "exact",
          properties: [
            %{"type" => "com.example.event", "source" => "loom"}
          ]
        }

      assert Filter.matches_event?(filter, event)
    end

    test "returns false for an exact match with one param missing" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "exact",
          properties: [
            %{"type" => "com.example.event", "subject" => "https://example.com/events"}
          ]
        }

      refute Filter.matches_event?(filter, event)
    end

    test "returns false for an exact match with one param different" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "exact",
          properties: [
            %{"type" => "com.example.event", "source" => "solvent"}
          ]
        }

      refute Filter.matches_event?(filter, event)
    end

    test "returns true for a prefix match when prefix is present" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "prefix",
          properties: [
            %{"type" => "com.example"}
          ]
        }

      assert Filter.matches_event?(filter, event)
    end

    test "returns false for a prefix match when not all fields have the prefix" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "prefix",
          properties: [
            %{"type" => "com.example", "subject" => "https://example.com"}
          ]
        }

      refute Filter.matches_event?(filter, event)
    end

    test "returns true for a suffix match when suffix is present" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "suffix",
          properties: [
            %{"type" => ".event"}
          ]
        }

      assert Filter.matches_event?(filter, event)
    end

    test "returns false for a suffix match when not all fields have the prefix" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "suffix",
          properties: [
            %{"type" => ".event", "subject" => "/event"}
          ]
        }

      refute Filter.matches_event?(filter, event)
    end

    test "returns true for an all match when all subfilters match" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "all",
          properties: [
            %Filter{dialect: "exact", properties: [%{"type" => "com.example.event"}]},
            %Filter{dialect: "exact", properties: [%{"source" => "loom"}]}
          ]
        }

      assert Filter.matches_event?(filter, event)
    end

    test "returns false for an all match when a subfilter doesn't match" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "all",
          properties: [
            %Filter{dialect: "exact", properties: [%{"type" => "com.example.event"}]},
            %Filter{dialect: "exact", properties: [%{"source" => "solvent"}]}
          ]
        }

      refute Filter.matches_event?(filter, event)
    end

    test "returns true for an any match when a subfilter matches" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "any",
          properties: [
            %Filter{dialect: "exact", properties: [%{"type" => "com.example.event"}]},
            %Filter{dialect: "exact", properties: [%{"source" => "solvent"}]}
          ]
        }

      assert Filter.matches_event?(filter, event)
    end

    test "returns false for an any match when all subfilters don't match" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "any",
          properties: [
            %Filter{dialect: "exact", properties: [%{"type" => "com.github.event"}]},
            %Filter{dialect: "exact", properties: [%{"source" => "solvent"}]}
          ]
        }

      refute Filter.matches_event?(filter, event)
    end

    test "returns false when using not and the subfilter is true" do
      event = Cloudevents.from_map!(%{specversion: "1.0", source: "loom", id: "abc123", type: "com.example.event"})

      filter =
        %Filter{
          dialect: "not",
          properties: [
            %Filter{dialect: "exact", properties: [%{"type" => "com.example.event"}]},
          ]
        }

      refute Filter.matches_event?(filter, event)
    end
  end
end

defmodule Loom.AdaptersTest do
  use ExUnit.Case, async: true
  alias Loom.Adapters
  doctest Loom.Adapters

  test "converts an AWS S3 events to a CloudEvent" do
    s3event =
      File.read!("test/support/fixtures/aws_s3_event.v2.2.json")
      |> Jason.decode!()

    cloudevent = Adapters.aws_s3_to_cloudevent(s3event)

    assert cloudevent.id == "Amazon S3 generated request ID.Amazon S3 host that processed the request"
    assert cloudevent.source == "aws:s3.us-west-2.bucket-name"
    assert cloudevent.type == "com.amazonaws.s3.event-type"
    assert cloudevent.datacontenttype == "application/json"
    assert cloudevent.data == Jason.encode!(s3event)
    assert cloudevent.subject == "object-key"
    assert cloudevent.time == "1970-01-01T00:00:00.000Z"
    assert is_nil(cloudevent.dataschema)
  end
end

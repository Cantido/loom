defmodule Loom.Store.S3InsertWorker do
  use Oban.Worker

  require OpenTelemetry.Tracer

  @impl true
  def perform(%Oban.Job{args: args}) do
    key = Loom.Store.event_key(args["event_source"], args["event_id"])

    OpenTelemetry.Tracer.with_span "loom.s3:put_object" do
      ExAws.S3.put_object("events", key, args["event_json"])
      |> ExAws.request()
    end
  end
end

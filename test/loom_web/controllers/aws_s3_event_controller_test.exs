defmodule LoomWeb.AwsS3EventControllerTest do
  use LoomWeb.ConnCase, async: true

  test "creates an event from an S3 event", %{conn: conn} do
    source_name = "aws:s3.us-west-2.bucket-name"
    {:ok, account} = Loom.Accounts.create_account(%{email: "email@example.com"})
    {:ok, source} = Loom.Store.create_source(account, source_name)
    s3event = File.read!("test/support/fixtures/aws_s3_event.v2.2.json") |> Jason.decode!()
    conn = post(conn, Routes.aws_s3_event_path(conn, :create), s3event)

    assert response(conn, 200)

    {:ok, event} = Loom.Store.fetch(source_name, "Amazon S3 generated request ID.Amazon S3 host that processed the request")

  end
end

defmodule LoomWeb.AwsS3EventControllerTest do
  use LoomWeb.ConnCase, async: true

  test "creates an event from an S3 event", %{conn: conn} do
    s3event = File.read!("test/support/fixtures/aws_s3_event.v2.2.json") |> Jason.decode!()
    conn = post(conn, Routes.aws_s3_event_path(conn, :create), s3event)

    assert response(conn, 200)
  end
end

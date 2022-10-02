defmodule LoomWeb.AwsS3EventController do
  use LoomWeb, :controller

  require Logger

  def create(conn, params) do
    event = Loom.Adapters.aws_s3_to_cloudevent(params)

    Logger.debug(inspect(event, pretty: true))

    {:ok, _} = Loom.Store.append(event)


    conn
    |> put_status(:ok)
    |> render(:create)
  end
end

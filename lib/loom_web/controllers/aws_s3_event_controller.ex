defmodule LoomWeb.AwsS3EventController do
  use LoomWeb, :controller

  def create(conn, params) do
    event = Loom.Adapters.aws_s3_to_cloudevent(params)



  end
end

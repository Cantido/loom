defmodule Loom.Adapters do
  def aws_s3_to_cloudevent(s3event) do
    body = s3event["Records"] |> List.first()

    Cloudevents.from_map!(%{
      specversion: "1.0",
      id: body["responseElements"]["x-amz-request-id"] <> "." <> body["responseElements"]["x-amz-id-2"],
      type: "com.amazonaws.s3." <> body["eventName"],
      source: body["eventSource"] <> "." <> body["awsRegion"] <> "." <> body["s3"]["bucket"]["name"],
      datacontenttype: "application/json",
      data: Jason.encode!(s3event),
      subject: body["s3"]["object"]["key"],
      time: body["eventTime"]
    })
  end
end

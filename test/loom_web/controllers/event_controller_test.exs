defmodule LoomWeb.EventControllerTest do
  use LoomWeb.ConnCase

  alias Loom.Accounts
  alias Loom.Store
  alias Loom.Repo

  import Loom.AccountsFixtures
  import Loom.StoreFixtures

  @source "loom-web-event-controller-test"

  @create_attrs %{
    id: "some id",
    source: @source,
    type: "com.example.event",
    specversion: "1.0"
  }
  @invalid_attrs %{id: nil}

  require Logger

  setup %{conn: conn} do
    account = account_fixture()
    source = source_fixture(%{account: account, source: @source})
    token = token_fixture(%{account: account})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", Plug.BasicAuth.encode_basic_auth(token.username, token.password))

    %{
      conn: conn,
      account: account,
      source: source
    }
  end

  describe "create event" do
    test "renders event when data is valid", %{conn: conn} do
      conn =
        post(conn, Routes.event_path(conn, :create), event: @create_attrs, stream_id: "ohayo")

      assert %{"id" => "some id"} = json_response(conn, 201)
    end
  end

  describe "show event" do
    test "renders an event", %{conn: conn, account: account} do
      event =
        Cloudevents.from_map!(%{
          specversion: "1.0",
          id: "12345",
          source: @source,
          type: "com.example.event"
        })

      {:ok, _revision} = Loom.append(event, account)

      conn = get(conn, Routes.event_path(conn, :show, @source, "12345"))

      json_body = json_response(conn, 200)
      assert json_body["id"] == "12345"
      assert json_body["source"] == @source
      assert json_body["type"] == "com.example.event"
      assert json_body["specversion"] == "1.0"
      assert Map.has_key?(json_body, "time")
      assert json_body["sequence"] == 1
    end

    test "includes an etag header", %{conn: conn, account: account} do
      event =
        Cloudevents.from_map!(%{
          specversion: "1.0",
          id: "12345",
          source: @source,
          type: "com.example.event"
        })

      {:ok, _revision} = Loom.append(event, account)

      conn = get(conn, Routes.event_path(conn, :show, @source, "12345"))

      assert [header] = get_resp_header(conn, "etag")
      assert String.starts_with?(header, ~s("))
      assert String.ends_with?(header, ~s("))
    end

    test "includes an last-modified header", %{conn: conn, account: account} do
      event =
        Cloudevents.from_map!(%{
          specversion: "1.0",
          id: "12345",
          source: @source,
          type: "com.example.event"
        })

      {:ok, _revision} = Loom.append(event, account)

      conn = get(conn, Routes.event_path(conn, :show, @source, "12345"))

      assert response(conn, 200) != ""
      assert [header] = get_resp_header(conn, "last-modified")
      last_modified = Timex.parse!(header, "{RFC1123}")
      assert Timex.before?(last_modified, Timex.now())
    end

    test "includes a cache-control header", %{conn: conn, account: account} do
      event =
        Cloudevents.from_map!(%{
          specversion: "1.0",
          id: "12345",
          source: @source,
          type: "com.example.event"
        })

      {:ok, _revision} = Loom.append(event, account)

      conn = get(conn, Routes.event_path(conn, :show, @source, "12345"))

      assert [header] = get_resp_header(conn, "cache-control")
      assert header == "public, max-age=31536000, immutable"
    end

    test "returns 304 if the etag is the same", %{conn: conn, account: account} do
      event =
        Cloudevents.from_map!(%{
          specversion: "1.0",
          id: "12345",
          source: @source,
          type: "com.example.event"
        })

      {:ok, _revision} = Loom.append(event, account)
      conn1 = get(conn, Routes.event_path(conn, :show, @source, "12345"))
      assert response(conn1, 200) != ""

      etag = List.first(get_resp_header(conn1, "etag"))

      conn = put_req_header(conn, "if-none-match", etag)
      conn = get(conn, Routes.event_path(conn, :show, @source, "12345"))

      assert response(conn, 304) == ""

      assert [header] = get_resp_header(conn, "cache-control")
      assert header == "public, max-age=31536000, immutable"
    end

    test "returns 304 if the modified time is before the if-modified-since header", %{conn: conn, account: account} do
      event =
        Cloudevents.from_map!(%{
          specversion: "1.0",
          id: "12345",
          source: @source,
          type: "com.example.event"
        })

      {:ok, _revision} = Loom.append(event, account)

      if_modified_since = Timex.format!(Timex.shift(Timex.now(), seconds: 1), "{RFC1123}")

      conn = put_req_header(conn, "if-modified-since", if_modified_since)
      conn = get(conn, Routes.event_path(conn, :show, @source, "12345"))

      assert response(conn, 304) == ""
      assert [header] = get_resp_header(conn, "cache-control")
      assert header == "public, max-age=31536000, immutable"
    end

    test "returns 404 when event does not exist", %{conn: conn} do
      conn = get(conn, Routes.event_path(conn, :show, @source, "12345"))

      assert json_response(conn, 404)["errors"] == [%{"title" => "Not Found"}]
    end
  end

  describe "show stream" do
    test "returns all events in a stream", %{conn: conn, account: account} do
      event1 =
        Cloudevents.from_map!(%{
          id: "uuid-1",
          source: @source,
          type: "com.example.event",
          specversion: "1.0"
        })

      event2 =
        Cloudevents.from_map!(%{
          id: "uuid-2",
          source: @source,
          type: "com.example.event",
          specversion: "1.0"
        })

      {:ok, 1} = Loom.append(event1, account)
      {:ok, 2} = Loom.append(event2, account)

      conn = get(conn, Routes.event_path(conn, :stream), stream_id: @source)

      assert [actual_event1, actual_event2] = json_response(conn, 200)
      assert actual_event1["id"] == "uuid-1"
      assert actual_event2["id"] == "uuid-2"
    end

    test "returns events in a stream when limited", %{conn: conn, account: account} do
      event1 =
        Cloudevents.from_map!(%{
          id: "uuid-1",
          source: @source,
          type: "com.example.event",
          specversion: "1.0"
        })

      event2 =
        Cloudevents.from_map!(%{
          id: "uuid-2",
          source: @source,
          type: "com.example.event",
          specversion: "1.0"
        })

      {:ok, 1} = Loom.append(event1, account)
      {:ok, 2} = Loom.append(event2, account)

      conn = get(conn, Routes.event_path(conn, :stream), stream_id: @source, limit: 1)

      assert [actual_event1] = json_response(conn, 200)
      assert actual_event1["id"] == "uuid-1"
    end

    test "returns the stream from a given point", %{conn: conn, account: account} do
      event1 =
        Cloudevents.from_map!(%{
          id: "uuid-1",
          source: @source,
          type: "com.example.event",
          specversion: "1.0"
        })

      event2 =
        Cloudevents.from_map!(%{
          id: "uuid-2",
          source: @source,
          type: "com.example.event",
          specversion: "1.0"
        })

      {:ok, 1} = Loom.append(event1, account)
      {:ok, 2} = Loom.append(event2, account)

      conn =
        get(conn, Routes.event_path(conn, :stream),
          stream_id: @source,
          from_revision: 2
        )

      assert [actual_event1] = json_response(conn, 200)
      assert actual_event1["id"] == "uuid-2"
    end

    test "returns the stream backwards", %{conn: conn, account: account} do
      event1 =
        Cloudevents.from_map!(%{
          id: "uuid-1",
          source: @source,
          type: "com.example.event",
          specversion: "1.0"
        })

      event2 =
        Cloudevents.from_map!(%{
          id: "uuid-2",
          source: @source,
          type: "com.example.event",
          specversion: "1.0"
        })

      {:ok, 1} = Loom.append(event1, account)
      {:ok, 2} = Loom.append(event2, account)

      conn =
        get(conn, Routes.event_path(conn, :stream),
          stream_id: @source,
          direction: "backward",
          from_revision: "end"
        )

      assert [actual_event2, actual_event1] = json_response(conn, 200)
      assert actual_event2["id"] == "uuid-2"
      assert actual_event1["id"] == "uuid-1"
    end
  end
end

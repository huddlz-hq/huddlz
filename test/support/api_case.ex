defmodule HuddlzWeb.ApiCase do
  @moduledoc """
  Test case template for API tests (JSON:API and GraphQL).

  Like `HuddlzWeb.ConnCase` but with API-specific helpers:

    * `authenticated_conn/2` — adds a bearer JWT for the given user
    * `gql_post/3` — POST a GraphQL query to `/gql` with optional variables

  More helpers (`api_key_conn/2`) land alongside the API key strategy
  in a later commit.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint HuddlzWeb.Endpoint

      use HuddlzWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import HuddlzWeb.ApiCase
      import Huddlz.Test.MoxHelpers
      import Huddlz.Generator
    end
  end

  setup tags do
    Huddlz.DataCase.setup_sandbox(tags)

    Mox.stub_with(Huddlz.MockGeocoding, Huddlz.GeocodingStub)
    Mox.stub_with(Huddlz.MockPlaces, Huddlz.PlacesStub)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Adds a bearer JWT for the given user to the conn's `authorization` header.
  """
  @spec authenticated_conn(Plug.Conn.t(), Huddlz.Accounts.User.t()) :: Plug.Conn.t()
  def authenticated_conn(conn, user) do
    case AshAuthentication.Jwt.token_for_user(user, %{}, domain: Huddlz.Accounts) do
      {:ok, token, _claims} ->
        Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> token)

      {:error, reason} ->
        raise "Failed to generate JWT for test user: #{inspect(reason)}"
    end
  end

  @doc """
  POSTs a GraphQL query to `/gql`. Variables are merged into the request body.
  """
  @spec gql_post(Plug.Conn.t(), String.t(), map()) :: Plug.Conn.t()
  def gql_post(conn, query, variables \\ %{}) do
    body = %{"query" => query, "variables" => variables}

    conn
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Phoenix.ConnTest.dispatch(HuddlzWeb.Endpoint, :post, "/gql", body)
  end

  @doc """
  Mints an API key for the user and adds it to the conn's `authorization`
  header as `Bearer <plaintext_api_key>`.
  """
  @spec api_key_conn(Plug.Conn.t(), Huddlz.Accounts.User.t(), keyword()) :: Plug.Conn.t()
  def api_key_conn(conn, user, opts \\ []) do
    expires_at =
      Keyword.get_lazy(opts, :expires_at, fn ->
        DateTime.utc_now() |> DateTime.add(7 * 24 * 3600, :second)
      end)

    record =
      Huddlz.Accounts.ApiKey
      |> Ash.Changeset.for_create(
        :create,
        %{expires_at: expires_at},
        actor: user
      )
      |> Ash.create!()

    Plug.Conn.put_req_header(
      conn,
      "authorization",
      "Bearer " <> record.__metadata__.plaintext_api_key
    )
  end

  @doc """
  POSTs a multipart `multipart/x.ash+form-data` request to a JSON:API
  upload route.

  The `data_attributes` map contains the JSON:API attributes — file
  fields are referenced by part name (e.g. `file: "the_file"`) and the
  part is supplied separately via the `:file` opt.

      multipart_post(conn, "/api/json/huddl_images/upload",
        %{"huddl_id" => h.id, "file" => "the_file"},
        file: %{
          part_name: "the_file",
          path: "test/fixtures/test_image.jpg",
          filename: "banner.jpg",
          content_type: "image/jpeg"
        }
      )
  """
  @spec multipart_post(Plug.Conn.t(), String.t(), map(), keyword()) :: Plug.Conn.t()
  def multipart_post(conn, path, data_attributes, opts) do
    type = Keyword.get(opts, :type, "huddl_image")
    file = Keyword.fetch!(opts, :file)

    boundary = "----huddlztest" <> Integer.to_string(System.unique_integer([:positive]))

    # AshJsonApi.Plug.Parser wraps the parsed JSON under {"data" => ...} —
    # we only send the inner resource object.
    json_envelope =
      Jason.encode!(%{
        "type" => type,
        "attributes" => data_attributes
      })

    body = build_ash_multipart(boundary, json_envelope, file)

    conn
    |> Plug.Conn.put_req_header(
      "content-type",
      "multipart/x.ash+form-data; boundary=#{boundary}"
    )
    |> Phoenix.ConnTest.dispatch(HuddlzWeb.Endpoint, :post, path, body)
  end

  defp build_ash_multipart(boundary, json_envelope, file) do
    file_bytes = File.read!(file.path)

    # The `data` part needs a filename so Plug's MULTIPART parser produces
    # a Plug.Upload — that's what AshJsonApi.Plug.Parser pattern-matches on
    # to recognize the JSON envelope. Without a filename it would be a plain
    # form field and the parser would silently produce an empty `data` map.
    [
      "--#{boundary}\r\n",
      ~s(Content-Disposition: form-data; name="data"; filename="data.json"\r\n),
      "Content-Type: application/vnd.api+json\r\n\r\n",
      json_envelope,
      "\r\n--#{boundary}\r\n",
      ~s(Content-Disposition: form-data; name="#{file.part_name}"; filename="#{file.filename}"\r\n),
      "Content-Type: #{file.content_type}\r\n\r\n",
      file_bytes,
      "\r\n--#{boundary}--\r\n"
    ]
    |> IO.iodata_to_binary()
  end
end

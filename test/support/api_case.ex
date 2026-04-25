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
end

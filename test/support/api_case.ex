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
end

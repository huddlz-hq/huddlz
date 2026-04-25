defmodule HuddlzWeb.Api.SensitiveFieldsAuditTest do
  @moduledoc """
  Locks down which fields our GraphQL schema exposes on the types that
  carry sensitive or admin-only data. Fails loudly if a future change
  inadvertently makes a private attribute public.

  Add an entry here whenever you expose a new resource type whose
  attributes you want to keep on a deny list.
  """

  use HuddlzWeb.ApiCase, async: true

  @forbidden_huddl_fields ~w(virtualLink virtual_link)
  # `User` is reachable via `me` query only, where the actor sees their own
  # record. `Author` / `UserPublicProfile` are cross-user shapes — they
  # MUST NOT leak email / role / hashed_password.
  @forbidden_self_fields ~w(role hashedPassword hashed_password)
  @forbidden_others_fields ~w(email role hashedPassword hashed_password homeLatitude homeLongitude)

  describe "Huddl GraphQL type" do
    test "does not expose virtual_link directly", %{conn: conn} do
      fields = type_field_names(conn, "Huddl")
      refute Enum.empty?(fields), "Huddl type should be present in the schema"

      for f <- @forbidden_huddl_fields do
        refute f in fields, "Huddl type unexpectedly exposes #{f}"
      end
    end
  end

  describe "User GraphQL type (only reachable via `me` query)" do
    test "does not expose role or hashed_password", %{conn: conn} do
      fields = type_field_names(conn, "User")

      for f <- @forbidden_self_fields do
        refute f in fields, "User type unexpectedly exposes #{f}"
      end
    end
  end

  describe "Cross-user GraphQL types (Author / UserPublicProfile)" do
    test "no User-relationship type exposes email or sensitive fields", %{conn: conn} do
      with_types =
        ~w(Author UserPublicProfile)
        |> Enum.map(&{&1, type_field_names(conn, &1)})
        |> Enum.reject(fn {_name, fields} -> fields == [] end)

      for {type_name, fields} <- with_types do
        for f <- @forbidden_others_fields do
          refute f in fields,
                 "GraphQL type #{type_name} unexpectedly exposes #{f}"
        end
      end
    end
  end

  defp type_field_names(conn, type_name) do
    query = """
    {
      __type(name: "#{type_name}") {
        fields { name }
      }
    }
    """

    response =
      conn
      |> gql_post(query)
      |> json_response(200)

    case response do
      %{"data" => %{"__type" => %{"fields" => fields}}} when is_list(fields) ->
        Enum.map(fields, & &1["name"])

      _ ->
        []
    end
  end
end

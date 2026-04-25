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
  @forbidden_user_fields ~w(email role hashedPassword hashed_password homeLatitude homeLongitude)

  describe "Huddl GraphQL type" do
    test "does not expose virtual_link directly", %{conn: conn} do
      fields = type_field_names(conn, "Huddl")
      refute Enum.empty?(fields), "Huddl type should be present in the schema"

      for f <- @forbidden_huddl_fields do
        refute f in fields, "Huddl type unexpectedly exposes #{f}"
      end
    end
  end

  describe "User-shaped GraphQL types (Author / Owner / public_profile)" do
    test "no User-typed object exposes email or role fields", %{conn: conn} do
      with_types =
        ~w(User Author UserPublicProfile)
        |> Enum.map(&{&1, type_field_names(conn, &1)})
        |> Enum.reject(fn {_name, fields} -> fields == [] end)

      for {type_name, fields} <- with_types do
        for f <- @forbidden_user_fields do
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

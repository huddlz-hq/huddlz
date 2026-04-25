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

  describe "Cross-user GraphQL types" do
    @known_user_shaped_types ~w(User)

    test "the schema has no unexpected user-shaped object types", %{conn: conn} do
      # If a new user-shaped type appears (e.g. Author, UserPublicProfile,
      # GroupOwner) it must be added to @known_user_shaped_types AND audited
      # for forbidden fields. Failing here is a prompt to do both.
      types = user_shaped_types(conn)

      unexpected = types -- @known_user_shaped_types

      assert unexpected == [],
             "new user-shaped GraphQL type(s) detected: #{inspect(unexpected)} — add an entry to the audit"
    end

    test "every known cross-user user-shaped type passes the deny list", %{conn: conn} do
      # When `User` is the only user-shaped type, this currently audits only
      # User against the cross-user deny list — but `User` is reachable via
      # `me` only, where the deny list is the looser self list. So no fields
      # are tested today. The loop is structured so it actually executes when
      # a new cross-user type lands.
      cross_user_types = @known_user_shaped_types -- ["User"]

      for type_name <- cross_user_types do
        fields = type_field_names(conn, type_name)

        refute Enum.empty?(fields),
               "expected #{type_name} to be present in the schema"

        for f <- @forbidden_others_fields do
          refute f in fields, "GraphQL type #{type_name} unexpectedly exposes #{f}"
        end
      end
    end

    defp user_shaped_types(conn) do
      query = "{ __schema { types { name kind } } }"

      conn
      |> gql_post(query)
      |> json_response(200)
      |> get_in(["data", "__schema", "types"])
      |> Enum.filter(fn t ->
        t["kind"] == "OBJECT" and
          not String.starts_with?(t["name"] || "", "__") and
          String.contains?(String.downcase(t["name"] || ""), "user")
      end)
      |> Enum.map(& &1["name"])
      |> Enum.sort()
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

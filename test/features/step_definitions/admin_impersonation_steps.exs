defmodule AdminImpersonationSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

  step "I am told I cannot edit {string}", %{args: [name], session: session} = context do
    group = find_group(name)

    session
    |> assert_path("/groups/#{group.slug}")
    |> assert_has("*", text: "You don't have permission to edit this group")

    context
  end

  step "{string} cannot rename {string} through the API", %{args: [email, name]} = context do
    group = find_group(name)

    response =
      gql_as(
        email,
        ~s|mutation { updateGroup(id: "#{group.id}", input: {name: "Renamed"}) { result { id } errors { message } } }|
      )

    assert response["data"]["updateGroup"]["result"] == nil
    assert response["data"]["updateGroup"]["errors"] != []
    assert to_string(find_group(name).name) == name
    context
  end

  step "{string} cannot transfer ownership of {string}", %{args: [email, name]} = context do
    group = find_group(name)
    target = find_user("member554@example.com")

    assert {:error, %Ash.Error.Forbidden{}} =
             Huddlz.Communities.transfer_group_ownership(group, target.id,
               actor: find_user(email)
             )

    assert find_group(name).owner_id == group.owner_id
    context
  end

  step "I am offered to schedule a huddl", %{session: session} = context do
    assert_has(session, "button", text: "Schedule huddl")
    context
  end

  defp gql_as(email, query) do
    build_conn()
    |> authenticated_conn(find_user(email))
    |> gql_post(query)
    |> json_response(200)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end
end

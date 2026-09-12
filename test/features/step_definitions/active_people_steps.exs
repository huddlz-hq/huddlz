defmodule ActivePeopleSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]

  require Ash.Query

  alias Huddlz.Accounts.{ActiveDay, User}
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, GroupMember}

  step "{string} is counted as active today", %{args: [email]} = context do
    assert active_days(email, Date.utc_today()) >= 1
    context
  end

  step "{string} is counted as active today once", %{args: [email]} = context do
    assert active_days(email, Date.utc_today()) == 1
    context
  end

  step "{string} is not counted as active today", %{args: [email]} = context do
    assert active_days(email, Date.utc_today()) == 0
    context
  end

  step "nobody is counted as active today", context do
    assert Ash.count!(ActiveDay, authorize?: false) == 0
    context
  end

  step "{string} reads their account through GraphQL", %{args: [email]} = context do
    response =
      build_conn()
      |> authenticated_conn(find_user(email))
      |> gql_post("{ me { id } }")
      |> json_response(200)

    assert response["data"]["me"]["id"] == find_user(email).id
    context
  end

  step "the owner removes {string} from {string}", %{args: [email, name]} = context do
    group =
      Group
      |> Ash.Query.filter(name == ^name)
      |> Ash.Query.load(:owner)
      |> Ash.read_one!(authorize?: false)

    member = find_user(email)

    membership =
      GroupMember
      |> Ash.Query.filter(group_id == ^group.id and user_id == ^member.id)
      |> Ash.read_one!(authorize?: false)

    Communities.remove_member!(membership, group.id, member.id, actor: group.owner)
    context
  end

  defp active_days(email, day) do
    user = find_user(email)

    ActiveDay
    |> Ash.Query.filter(user_id == ^user.id and day == ^day)
    |> Ash.count!(authorize?: false)
  end

  defp find_user(email),
    do: User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
end

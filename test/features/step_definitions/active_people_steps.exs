defmodule ActivePeopleSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]

  require Ash.Query
  require Ecto.Query

  alias Huddlz.Accounts.{ActiveDay, UsageMeasurement, User}
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, GroupMember}

  step "usage measurement began {int} days ago", %{args: [days]} = context do
    UsageMeasurement
    |> Ash.read_one!(authorize?: false)
    |> Ash.Seed.update!(%{started_on: Date.add(Date.utc_today(), -days)})

    context
  end

  step "the overview reports usage measured from {int} days ago", %{args: [days]} = context do
    active = context.overview_stats.active
    assert active.measured_from == Date.add(Date.utc_today(), -days)
    context
  end

  step "the overview reports {int} active people in the previous period",
       %{args: [count]} = context do
    assert context.overview_stats.active.previous == count
    context
  end

  step "the overview reports no active people comparison", context do
    assert context.overview_stats.active.previous == nil
    context
  end

  step "the account {string} has been deleted", %{args: [email]} = context do
    id = find_user(email).id
    Huddlz.Repo.delete_all(Ecto.Query.from(user in User, where: user.id == ^id))
    assert ActiveDay |> Ash.Query.filter(user_id == ^id) |> Ash.count!(authorize?: false) == 0
    context
  end

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

  step "{string} used huddlz {int} day ago", %{args: [email, days]} = context do
    seed_active_day(email, days)
    context
  end

  step "{string} used huddlz {int} days ago", %{args: [email, days]} = context do
    seed_active_day(email, days)
    context
  end

  step "the overview active people figure counts {int} people measured from {int} days ago with no comparison",
       %{args: [count, days]} = context do
    active = context.overview_stats.active
    assert active.count == count
    assert active.previous == nil
    assert active.measured_from == Date.add(Date.utc_today(), -days)
    assert Enum.any?(active.spark, &is_nil/1)
    context
  end

  defp seed_active_day(email, days_ago) do
    Ash.Seed.seed!(ActiveDay, %{
      user_id: find_user(email).id,
      day: Date.add(Date.utc_today(), -days_ago)
    })
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

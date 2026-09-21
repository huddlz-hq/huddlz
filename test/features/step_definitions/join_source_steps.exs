defmodule JoinSourceSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, GroupActivity, GroupMember}

  @sources %{
    "the huddl page" => :huddl_page,
    "the groups page" => :groups_page,
    "the group page" => :group_page,
    "the join suggestion email" => :join_suggestion_email,
    "the join suggestion notification" => :join_suggestion_notification,
    "the RSVP confirmation email" => :rsvp_confirmation_email
  }

  step "the join of {string} to {string} is recorded as coming from {string}",
       %{args: [email, group_name, source]} = context do
    assert_recorded(email, group_name, Map.fetch!(@sources, source))
    context
  end

  defp assert_recorded(email, group_name, source) do
    user = find_user(email)
    group = find_group(group_name)

    membership =
      GroupMember
      |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
      |> Ash.read_one!(authorize?: false)

    assert membership.join_source == source
    assert joined_entry(group, user).source == source
  end

  defp joined_entry(group, user) do
    GroupActivity
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id and kind == :joined)
    |> Ash.Query.sort(occurred_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end
end

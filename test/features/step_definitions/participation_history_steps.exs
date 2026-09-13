defmodule ParticipationHistorySteps do
  use Cucumber.StepDefinition

  import Ecto.Query, only: [from: 2]
  import ExUnit.Assertions

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, GroupMember, Huddl, HuddlAttendee}
  alias Huddlz.Repo

  step "{string} RSVPed to {string} a year ago", %{args: [email, title]} = context do
    huddl = find_huddl(title)
    Communities.rsvp_huddl!(huddl, actor: find_user(email))
    backdate(HuddlAttendee.Version, attendee_ids(huddl), days_ago(365))
    context
  end

  step "{string} RSVPed to {string}", %{args: [email, title]} = context do
    Communities.rsvp_huddl!(find_huddl(title), actor: find_user(email))
    context
  end

  step "{string} joined {string} two years and a day ago", %{args: [email, name]} = context do
    group = find_group(name)
    user = find_user(email)
    Communities.join_group!(group.id, actor: user)
    backdate(GroupMember.Version, membership_ids(group, user), days_ago(731))
    context
  end

  # Through the actions, so each step leaves a version; the dates are moved
  # back afterwards, versions included.
  step "{string} was created, edited and had its turnout recorded four months ago",
       %{args: [title]} = context do
    group = find_group("Portland Elixir")
    owner = Ash.get!(User, group.owner_id, authorize?: false)
    starts_at = DateTime.add(DateTime.utc_now(), 3, :day)

    huddl =
      Communities.create_huddl!(
        %{
          title: title,
          description: "Looking back on the quarter",
          group_id: group.id,
          event_type: :virtual,
          virtual_link: "https://meet.example.com/retro",
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, 1, :hour),
          is_private: false
        },
        actor: owner
      )

    huddl =
      Communities.update_huddl!(
        huddl,
        %{title: "#{title} (edited)", description: "Updated plans for the quarter"},
        actor: owner
      )

    ended_at = days_ago(120)

    huddl =
      Ash.Seed.update!(huddl, %{
        starts_at: DateTime.add(ended_at, -1, :hour),
        ends_at: ended_at,
        lifecycle_state: :completed
      })

    Communities.record_turnout!(huddl, %{on_call: 3}, actor: owner)
    backdate(Huddl.Version, [huddl.id], ended_at)
    Map.put(context, :huddl_id, huddl.id)
  end

  step "the daily pruning runs", context do
    assert :ok = Huddlz.Audit.prune()
    context
  end

  step "the RSVP by {string} to {string} is still on record", %{args: [email, title]} = context do
    assert [_ | _] = attendee_versions(find_user(email), find_huddl(title), :rsvp)
    context
  end

  step "the join by {string} to {string} is no longer on record",
       %{args: [email, name]} = context do
    assert [] = member_versions(find_user(email), find_group(name), :join_group)
    context
  end

  step "the creation of {string} and its turnout recording are still on record",
       %{args: [_title]} = context do
    actions = context.huddl_id |> huddl_versions() |> Enum.map(& &1.version_action_name)
    assert :create in actions
    assert :record_turnout in actions
    context
  end

  step "the original and edited descriptions of {string} are still on record",
       %{args: [_title]} = context do
    versions = huddl_versions(context.huddl_id)

    assert Enum.any?(
             versions,
             &(&1.version_action_name == :create and
                 &1.changes["description"] == "Looking back on the quarter")
           )

    assert Enum.any?(
             versions,
             &(&1.version_action_name == :update and
                 &1.changes["description"] == "Updated plans for the quarter")
           )

    context
  end

  step "{string} cancels the RSVP to {string}", %{args: [email, title]} = context do
    Communities.cancel_rsvp_huddl!(find_huddl(title), actor: find_user(email))
    context
  end

  step "the RSVP and the cancellation by {string} are both on record",
       %{args: [email]} = context do
    user = find_user(email)
    huddl = find_huddl("Kickoff")
    assert [rsvp] = attendee_versions(user, huddl, :rsvp)
    assert [cancel] = attendee_versions(user, huddl, :cancel_rsvp)
    assert rsvp.actor_id == user.id
    assert cancel.actor_id == user.id
    context
  end

  step "the removal names {string} as the actor and {string} as the person removed",
       %{args: [owner_email, email]} = context do
    owner = find_user(owner_email)
    member = find_user(email)
    assert [removal] = member_versions(member, find_group("Portland Elixir"), :remove_member)
    assert removal.actor_id == owner.id
    assert removal.changes["user_id"] == member.id
    context
  end

  step "{string} had its description changed {int} days ago",
       %{args: [name, days]} = context do
    group = find_group(name)
    owner = Ash.get!(User, group.owner_id, authorize?: false)

    group
    |> Ash.Changeset.for_update(:update_details, %{description: "Weekly Elixir conversations"},
      actor: owner
    )
    |> Ash.update!()

    backdate(Group.Version, [group.id], days_ago(days))
    context
  end

  step "the edited description of {string} is still on record", %{args: [name]} = context do
    assert [version] = group_edits(find_group(name))
    assert version.changes["description"] == "Weekly Elixir conversations"
    context
  end

  step "the edited description of {string} is no longer on record", %{args: [name]} = context do
    assert [] = group_edits(find_group(name))
    context
  end

  defp group_edits(group) do
    Group.Version
    |> Ash.Query.filter(version_source_id == ^group.id and version_action_name == :update_details)
    |> Ash.read!(authorize?: false)
  end

  defp attendee_versions(user, huddl, action) do
    HuddlAttendee.Version
    |> Ash.Query.filter(version_action_name == ^action)
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&(&1.changes["user_id"] == user.id and &1.changes["huddl_id"] == huddl.id))
  end

  defp member_versions(user, group, action) do
    GroupMember.Version
    |> Ash.Query.filter(version_action_name == ^action)
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&(&1.changes["user_id"] == user.id and &1.changes["group_id"] == group.id))
  end

  defp huddl_versions(huddl_id) do
    Huddl.Version
    |> Ash.Query.filter(version_source_id == ^huddl_id)
    |> Ash.read!(authorize?: false)
  end

  defp attendee_ids(huddl) do
    HuddlAttendee
    |> Ash.Query.filter(huddl_id == ^huddl.id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  defp membership_ids(group, user) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  # Versions are written now; the scenario says when they happened.
  defp backdate(version_module, source_ids, at) do
    Repo.update_all(from(v in version_module, where: v.version_source_id in ^source_ids),
      set: [version_inserted_at: at]
    )
  end

  defp days_ago(days), do: DateTime.add(DateTime.utc_now(), -days, :day)

  defp find_user(email),
    do: User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)

  defp find_group(name),
    do: Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)

  defp find_huddl(title) do
    Huddl
    |> Ash.Query.filter(title == ^title)
    |> Ash.Query.load(:group)
    |> Ash.read_one!(authorize?: false)
  end
end

defmodule DropInJoinSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, GroupMember, Huddl}

  step "I can join {string} from the huddl page", %{args: [_group_name]} = context do
    assert_has(context.session, "#huddl-group button", text: "Join group")
    context
  end

  step "I join {string} from the huddl page", %{args: [_group_name]} = context do
    session = within(context.session, "#huddl-group", &click_button(&1, "Join group"))
    Map.put(context, :session, session)
  end

  step "I am shown as a member of {string} on the huddl page", %{args: [_group_name]} = context do
    assert_has(context.session, "#huddl-group", text: "Member")
    refute_has(context.session, "#huddl-group button", text: "Join group")
    context
  end

  step "{string} has RSVPd to {string}", %{args: [email, title]} = context do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
    huddl = Huddl |> Ash.Query.filter(title == ^title) |> Ash.read_one!(authorize?: false)
    Communities.rsvp_huddl!(huddl, actor: user)
    context
  end

  step "the huddl page suggests joining {string}", %{args: [group_name]} = context do
    assert_has(context.session, "#huddl-join-suggestion",
      text: "Join #{group_name} to hear about their next huddlz."
    )

    context
  end

  step "the huddl page does not suggest joining {string}", %{args: [_group_name]} = context do
    refute_has(context.session, "#huddl-join-suggestion")
    context
  end

  step "I join {string} from the suggestion", %{args: [_group_name]} = context do
    session =
      within(context.session, "#huddl-join-suggestion", &click_button(&1, "Join group"))

    Map.put(context, :session, session)
  end

  step "I decline the suggestion to join {string}", %{args: [_group_name]} = context do
    session = within(context.session, "#huddl-join-suggestion", &click_button(&1, "Not now"))
    Map.put(context, :session, session)
  end

  step "{string} joined and then left {string}", %{args: [email, group_name]} = context do
    user = find_user(email)
    membership = Communities.join_group!(find_group(group_name).id, actor: user)
    :ok = Communities.leave_group!(membership, actor: user)
    context
  end

  step "{string} joined {string} and was removed by {string}",
       %{args: [email, group_name, organizer_email]} = context do
    user = find_user(email)
    group = find_group(group_name)
    membership = Communities.join_group!(group.id, actor: user)

    :ok =
      Communities.remove_member!(membership, group.id, user.id, actor: find_user(organizer_email))

    context
  end

  step "{string} does not belong to {string}", %{args: [email, group_name]} = context do
    refute membership(email, group_name)
    context
  end

  step "{string} belongs to {string}", %{args: [email, group_name]} = context do
    assert membership(email, group_name)
    context
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp membership(email, group_name) do
    user = find_user(email)
    group = find_group(group_name)

    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.read_one!(authorize?: false)
  end
end

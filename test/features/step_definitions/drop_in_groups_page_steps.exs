defmodule DropInGroupsPageSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, HuddlAttendee}

  @section "#dropped-in-groups"

  step "{string} held an RSVP to {string} in {string} when it completed",
       %{args: [email, title, group_name]} = context do
    group = find_group(group_name)

    huddl =
      generate(
        past_huddl(
          title: title,
          group_id: group.id,
          creator_id: group.owner_id,
          is_private: false,
          lifecycle_state: :completed
        )
      )

    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: find_user(email).id})
    |> Ash.create!(authorize?: false)

    context
  end

  step "{string} has dropped in on {int} public groups", %{args: [email, count]} = context do
    person = find_user(email)

    for n <- 1..count//1 do
      owner = generate(user(role: :user))

      group =
        generate(group(owner_id: owner.id, actor: owner, is_public: true, name: "Club #{n}"))

      huddl = generate(huddl(group_id: group.id, creator_id: owner.id, is_private: false))
      Communities.rsvp_huddl!(huddl, actor: person)
    end

    context
  end

  step "{string} is listed among groups I've dropped in on", %{args: [group_name]} = context do
    assert_has(context.session, "#{@section} article", text: group_name)
    context
  end

  step "{int} groups are listed among groups I've dropped in on", %{args: [count]} = context do
    assert_has(context.session, "#{@section} article", count: count)
    context
  end

  step "its listing says I'm going to {string}", %{args: [title]} = context do
    assert_has(context.session, "#{@section} article", text: "You're going to #{title} on")
    context
  end

  step "its listing says I RSVPd to {string}", %{args: [title]} = context do
    assert_has(context.session, "#{@section} article", text: "You RSVPd to #{title} on")
    context
  end

  step "its listing says I'm waitlisted for {string}", %{args: [title]} = context do
    assert_has(context.session, "#{@section} article", text: "Waitlisted for #{title} on")
    context
  end

  step "I join {string} from the groups I've dropped in on", %{args: [group_name]} = context do
    Map.put(context, :session, click_in_card(context.session, group_name, "Join group"))
  end

  step "I choose not now for {string}", %{args: [group_name]} = context do
    Map.put(context, :session, click_in_card(context.session, group_name, "Not now"))
  end

  step "{string} is listed among my groups", %{args: [group_name]} = context do
    assert_has(context.session, "#my-groups", text: group_name)
    context
  end

  step "there is no section for groups I've dropped in on", context do
    refute_has(context.session, @section)
    context
  end

  defp click_in_card(session, group_name, button) do
    group = find_group(group_name)
    within(session, "#dropped-in-#{group.id}", &click_button(&1, button))
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end
end

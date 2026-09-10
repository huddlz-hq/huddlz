defmodule OrganizeTurnoutSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, Huddl, HuddlAttendee}

  step "the {word} huddl {string} in {string} ended {int} days ago with {int} RSVPs",
       %{args: [kind, title, group_name, days, rsvps]} = context do
    group = Group |> Ash.Query.filter(name == ^group_name) |> Ash.read_one!(authorize?: false)
    starts_at = DateTime.add(DateTime.utc_now(), -days, :day)

    attrs = [
      title: title,
      group_id: group.id,
      creator_id: group.owner_id,
      is_private: false,
      starts_at: starts_at,
      ends_at: DateTime.add(starts_at, 2, :hour)
    ]

    huddl = generate(past_huddl(attrs ++ kind_attrs(kind)))

    for _ <- 1..rsvps//1 do
      attendee = generate(user(role: :user))

      HuddlAttendee
      |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: attendee.id})
      |> Ash.create!(authorize?: false)
    end

    Map.update(context, :huddlz, [huddl], &[huddl | &1])
  end

  step "the turnout for {string} was recorded as {int} in the room and {int} on the call",
       %{args: [title, in_room, on_call]} = context do
    huddl = find_huddl(title)
    owner = Ash.get!(User, huddl.group.owner_id, authorize?: false)
    Communities.record_turnout!(huddl, %{in_room: in_room, on_call: on_call}, actor: owner)
    context
  end

  step "the turnout prompt for {string} was skipped", %{args: [title]} = context do
    huddl = find_huddl(title)
    owner = Ash.get!(User, huddl.group.owner_id, authorize?: false)
    Communities.skip_turnout!(huddl, actor: owner)
    context
  end

  step "the past row for {string} shows {string}, {string} and {string}",
       %{args: [title | texts], session: session} = context do
    assert_row_texts(session, find_huddl(title), texts)
    context
  end

  step "the past row for {string} shows {string} and {string}",
       %{args: [title | texts], session: session} = context do
    assert_row_texts(session, find_huddl(title), texts)
    context
  end

  step "the overview nudge names {string}", %{args: [title], session: session} = context do
    huddl = find_huddl(title)

    session
    |> assert_has("#turnout-nudge", text: title)
    |> assert_has("#turnout-nudge a[href='/groups/#{huddl.group.slug}/huddlz/#{huddl.id}']",
      text: "Add turnout"
    )

    context
  end

  step "the overview nudge does not name {string}",
       %{args: [title], session: session} = context do
    refute_has(session, "#turnout-nudge", text: title)
    context
  end

  step "there is no overview nudge", %{session: session} = context do
    refute_has(session, "#turnout-nudge")
    context
  end

  defp assert_row_texts(session, huddl, texts) do
    Enum.reduce(texts, session, fn text, session ->
      assert_has(session, "#organize-huddl-#{huddl.id}", text: text)
    end)
  end

  defp kind_attrs("in-person"), do: [event_type: :in_person, virtual_link: nil]

  defp kind_attrs("virtual"),
    do: [event_type: :virtual, physical_location: nil, virtual_link: "https://meet.example.com/x"]

  defp kind_attrs("hybrid"), do: [event_type: :hybrid, virtual_link: "https://meet.example.com/x"]

  defp find_huddl(title) do
    Huddl
    |> Ash.Query.filter(title == ^title)
    |> Ash.Query.load(:group)
    |> Ash.read_one!(authorize?: false)
  end
end

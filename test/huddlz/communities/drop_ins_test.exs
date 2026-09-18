defmodule Huddlz.Communities.DropInsTest do
  @moduledoc """
  Which huddl is mentioned for each dropped-in group, and the order the
  groups come back in. Which groups qualify at all is covered by
  `Huddlz.Communities.DropInGroupsTest`.
  """
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities
  alias Huddlz.Communities.DropIns
  alias Huddlz.Communities.HuddlAttendee

  setup do
    %{person: generate(user(role: :user))}
  end

  defp public_group(name) do
    owner = generate(user(role: :user))
    {generate(group(owner_id: owner.id, actor: owner, is_public: true, name: name)), owner}
  end

  defp upcoming(group, owner, opts) do
    generate(huddl([group_id: group.id, creator_id: owner.id, is_private: false] ++ opts))
  end

  defp completed(group, owner, opts) do
    generate(
      past_huddl(
        [group_id: group.id, creator_id: owner.id, is_private: false, lifecycle_state: :completed] ++
          opts
      )
    )
  end

  defp hold_rsvp(person, huddl) do
    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: person.id})
    |> Ash.create!(authorize?: false)
  end

  defp days_from_now(days), do: DateTime.add(DateTime.utc_now(), days, :day)

  test "nothing dropped in on is an empty list", %{person: person} do
    assert {:ok, []} = DropIns.list(person)
  end

  test "an upcoming huddl is mentioned ahead of a completed one", %{person: person} do
    {group, owner} = public_group("Tuesday Runners")
    hold_rsvp(person, completed(group, owner, title: "Track Night"))
    Communities.rsvp_huddl!(upcoming(group, owner, title: "Long Run"), actor: person)

    assert {:ok, [%{spot: :going, huddl: %{title: "Long Run"}}]} = DropIns.list(person)
  end

  test "the soonest upcoming huddl is the one mentioned", %{person: person} do
    {group, owner} = public_group("Tuesday Runners")

    later = upcoming(group, owner, title: "Later", date: Date.add(eastern_today(), 20))
    sooner = upcoming(group, owner, title: "Sooner", date: Date.add(eastern_today(), 5))

    Communities.rsvp_huddl!(later, actor: person)
    Communities.rsvp_huddl!(sooner, actor: person)

    assert {:ok, [%{huddl: %{title: "Sooner"}}]} = DropIns.list(person)
  end

  test "with only completed huddlz, the most recent is mentioned as RSVPd", %{person: person} do
    {group, owner} = public_group("Tuesday Runners")

    hold_rsvp(
      person,
      completed(group, owner,
        title: "Older",
        starts_at: days_from_now(-30),
        ends_at: days_from_now(-29)
      )
    )

    hold_rsvp(
      person,
      completed(group, owner,
        title: "Newer",
        starts_at: days_from_now(-3),
        ends_at: days_from_now(-2)
      )
    )

    assert {:ok, [%{spot: :rsvpd, huddl: %{title: "Newer"}}]} = DropIns.list(person)
  end

  test "a waitlist spot is reported as waitlisted", %{person: person} do
    {group, owner} = public_group("Board Game Night")
    huddl = upcoming(group, owner, title: "Catan League", max_attendees: 1)
    Communities.join_waitlist_huddl!(huddl, actor: person)

    assert {:ok, [%{spot: :waitlisted, huddl: %{title: "Catan League"}}]} = DropIns.list(person)
  end

  test "groups come back newest activity first", %{person: person} do
    {first_group, first_owner} = public_group("Alpha Club")
    {second_group, second_owner} = public_group("Zulu Club")

    Communities.rsvp_huddl!(upcoming(first_group, first_owner, title: "One"), actor: person)
    Communities.rsvp_huddl!(upcoming(second_group, second_owner, title: "Two"), actor: person)

    assert {:ok, [%{group: %{name: newest}}, %{group: %{name: oldest}}]} = DropIns.list(person)
    assert {to_string(newest), to_string(oldest)} == {"Zulu Club", "Alpha Club"}
  end

  test "another person's spots are never mentioned", %{person: person} do
    other = generate(user(role: :user))
    {group, owner} = public_group("Tuesday Runners")
    Communities.rsvp_huddl!(upcoming(group, owner, title: "Long Run"), actor: other)

    assert {:ok, []} = DropIns.list(person)

    assert {:ok, []} = Communities.list_drop_in_spots([group.id], actor: person)
  end
end

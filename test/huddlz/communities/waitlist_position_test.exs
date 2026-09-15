defmodule Huddlz.Communities.WaitlistPositionTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlAttendee

  test "a person can read their own position without seeing another person's position" do
    owner = generate(user())
    group = generate(group(actor: owner, is_public: true))
    huddl = generate(huddl(group_id: group.id, actor: owner))
    first = generate(user())
    second = generate(user())
    at = DateTime.add(DateTime.utc_now(), -10, :second)

    first_entry =
      Ash.Seed.seed!(HuddlAttendee, %{huddl_id: huddl.id, user_id: first.id, waitlisted_at: at})

    Ash.Seed.seed!(HuddlAttendee, %{
      huddl_id: huddl.id,
      user_id: second.id,
      waitlisted_at: DateTime.add(at, 1, :second)
    })

    assert [%{waitlist_position: 2}] =
             Communities.check_user_rsvp!(huddl.id, actor: second, load: [:waitlist_position])

    assert %{waitlist_position: nil} = Ash.load!(first_entry, :waitlist_position, actor: second)
    assert %{waitlist_position: nil} = Ash.load!(first_entry, :waitlist_position)
  end
end

defmodule Huddlz.Notifications.Senders.GroupJoinSuggestionTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Senders.GroupJoinSuggestion

  setup do
    owner = generate(user(role: :user))
    person = generate(user(role: :user, display_name: "Maya Chen"))

    group =
      generate(
        group(
          name: "Tuesday Runners",
          slug: "tuesday-runners",
          is_public: true,
          owner_id: owner.id,
          actor: owner
        )
      )

    rsvpd =
      generate(
        past_huddl(
          title: "Long Run",
          group_id: group.id,
          creator_id: owner.id,
          is_private: false,
          lifecycle_state: :completed
        )
      )

    %{owner: owner, person: person, group: group, payload: %{"huddl_id" => rsvpd.id}}
  end

  defp upcoming(%{group: group, owner: owner}, title, days, attrs \\ []) do
    generate(
      huddl(
        [
          title: title,
          group_id: group.id,
          creator_id: owner.id,
          actor: owner,
          is_private: false,
          date: Date.add(Huddlz.Generator.eastern_today(), days)
        ] ++ attrs
      )
    )
  end

  test "names the group and the huddl, says RSVPd, and has one button to the group page",
       %{person: person, payload: payload} do
    email = GroupJoinSuggestion.build(person, payload)

    assert email.to == [{"", to_string(person.email)}]
    assert email.from == Huddlz.Mailer.from()
    refute email.text_body =~ "<"
    assert email.subject == "Hear about Tuesday Runners's next huddlz"
    assert email.text_body =~ "TUESDAY RUNNERS\nHear about their next huddlz"
    assert email.text_body =~ "You RSVPd to Long Run on "
    assert email.text_body =~ "Tuesday Runners hosted it, and you're not a member yet."

    assert email.text_body =~
             "See Tuesday Runners: http://localhost:4002/groups/tuesday-runners\n"

    assert email.text_body =~ "This is the only time we'll suggest it for Tuesday Runners."
    refute email.text_body =~ ~r/\b(went|came|attended)\b/
  end

  test "lists the three soonest upcoming huddlz", %{person: person, payload: payload} = context do
    for {title, days} <- [{"Fourth", 12}, {"Second", 5}, {"First", 2}, {"Third", 9}] do
      upcoming(context, title, days)
    end

    email = GroupJoinSuggestion.build(person, payload)

    assert email.text_body =~ "Coming up:"
    assert email.text_body =~ ~r/First.*Second.*Third/s
    refute email.text_body =~ "Fourth"
    refute email.text_body =~ "Nothing is on their calendar yet."
  end

  test "leaves out huddlz the recipient cannot see",
       %{person: person, payload: payload} = context do
    upcoming(context, "Members Only Social", 3, is_private: true)

    email = GroupJoinSuggestion.build(person, payload)

    refute email.text_body =~ "Members Only Social"

    assert email.text_body =~
             "Nothing is on their calendar yet. Join and you'll hear as soon as something is."
  end

  test "escapes names in the HTML body", %{owner: owner, person: person} do
    group =
      generate(group(name: "Run <b>Club</b>", is_public: true, owner_id: owner.id, actor: owner))

    huddl =
      generate(
        past_huddl(
          title: "<script>x</script>",
          group_id: group.id,
          creator_id: owner.id,
          lifecycle_state: :completed
        )
      )

    email = GroupJoinSuggestion.build(person, %{"huddl_id" => huddl.id})

    refute email.html_body =~ "<script>x</script>"
    refute email.html_body =~ "Run <b>Club</b>"
  end

  test "requires the huddl id", %{person: person} do
    assert_raise ArgumentError, fn -> GroupJoinSuggestion.build(person, %{}) end
  end
end

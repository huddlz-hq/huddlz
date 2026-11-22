defmodule BrowserOverviewCardsSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest

  alias Huddlz.Communities.HuddlAttendee

  step "I have opened the overview of a group with an uncounted past huddl", context do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    starts_at = DateTime.add(DateTime.utc_now(), -2, :day)

    huddl =
      generate(
        past_huddl(
          title: "Elixir office hours",
          group_id: group.id,
          creator_id: owner.id,
          is_private: false,
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, 2, :hour)
        )
      )

    for _ <- 1..12 do
      attendee = generate(user(role: :user))

      HuddlAttendee
      |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: attendee.id})
      |> Ash.create!(authorize?: false)
    end

    conn =
      context.conn
      |> sign_in(owner)
      |> visit("/organize/#{group.slug}")
      |> assert_has(".phx-connected")
      |> assert_has("#turnout-nudge", text: "Elixir office hours")

    Map.merge(context, %{conn: conn, group: group})
  end

  step "the Show rate card is as tall as the RSVPs card", context do
    Map.put(context, :conn, assert_same_height(context.conn))
  end

  step "I record turnout from the overview reminder", context do
    conn =
      context.conn
      |> click_button("#turnout-nudge button", "Add turnout")
      |> fill_in("People in the room", with: 6)
      |> click_button("Save turnout")
      |> assert_has("#flash-info", text: "Turnout saved")

    Map.put(context, :conn, conn)
  end

  step "the Show rate card shows a rate and is still as tall as the RSVPs card", context do
    conn =
      context.conn
      |> assert_has("#kpi-showrate .value", text: "50%", exact: true)
      |> assert_has("#spark-showrate:not([data-empty])")
      |> assert_same_height()

    Map.put(context, :conn, conn)
  end

  defp assert_same_height(conn) do
    assert_browser(conn, """
    (() => {
      const rate = document.querySelector('#kpi-showrate').getBoundingClientRect();
      const rsvps = document.querySelector('#kpi-rsvps').getBoundingClientRect();
      const spark = document.querySelector('#spark-showrate').getBoundingClientRect();
      return Math.abs(rate.height - rsvps.height) < 1 && rate.bottom - spark.bottom < 24;
    })()
    """)
  end
end

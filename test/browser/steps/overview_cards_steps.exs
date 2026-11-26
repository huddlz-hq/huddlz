defmodule BrowserOverviewCardsSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  alias Huddlz.Communities.HuddlAttendee

  step "I have opened the overview of a group with an uncounted past huddl",
       %{session: session} do
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

    session
    |> sign_in(owner)
    |> visit("/organize/#{group.slug}")
    |> assert_has(by_css("#turnout-nudge") |> filter(has_text: "Elixir office hours"))

    %{group: group}
  end

  step "the Show rate card is as tall as the RSVPs card", %{session: session} do
    assert_same_height(session)
    :ok
  end

  step "I record turnout from the overview reminder", %{session: session} do
    session
    |> click(by_role(by_css("#turnout-nudge"), :button, name: "Add turnout"))
    |> fill(by_label("People in the room", exact: true), 6)
    |> click(by_role(:button, name: "Save turnout"))
    |> assert_has(by_css("#flash-info") |> filter(has_text: "Turnout saved"))

    :ok
  end

  step "the Show rate card shows a rate and is still as tall as the RSVPs card",
       %{session: session} do
    session
    |> assert(text(by_css("#kpi-showrate .value"), "50%"))
    |> assert_has(by_css("#spark-showrate:not([data-empty])"))
    |> assert_same_height()

    :ok
  end

  defp assert_same_height(session) do
    assert_browser(session, """
    (() => {
      const rate = document.querySelector('#kpi-showrate').getBoundingClientRect();
      const rsvps = document.querySelector('#kpi-rsvps').getBoundingClientRect();
      const spark = document.querySelector('#spark-showrate').getBoundingClientRect();
      return Math.abs(rate.height - rsvps.height) < 1 && rate.bottom - spark.bottom < 24;
    })()
    """)
  end
end

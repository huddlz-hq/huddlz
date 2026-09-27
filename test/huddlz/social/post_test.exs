defmodule Huddlz.Social.PostTest do
  use Huddlz.DataCase, async: true

  @moduletag :social_post

  import Huddlz.Generator

  alias Huddlz.Social.Post

  @link "https://huddlz.com/groups/elixir-nashville/huddlz/1"

  describe "text/2" do
    test "an in-person huddl with spots left, a week before" do
      date = thursday_at_least_a_week_out()
      huddl = generated_huddl(date, ~T[18:00:00], max_attendees: 20, going: 8)

      assert Post.text(huddl, moment: :week_before, opening_line: "This week:", link: @link) ==
               """
               This week:
               #{huddl.title}
               #{Calendar.strftime(date, "%a, %b %-d")} at 6:00 PM
               123 Main St, Anytown, USA
               12 spots left
               #{@link}
               """
               |> String.trim_trailing()
    end

    test "day-of posts say today, an online huddl says so, and no cap means no spots line" do
      huddl = huddl_like(~D[2026-10-01], ~T[09:30:00], event_type: :virtual)

      assert Post.lines(huddl, moment: :morning_of, link: @link) ==
               [huddl.title, "Today at 9:30 AM", "Online", @link]
    end

    test "other moments give the weekday and date where the huddl is" do
      huddl = huddl_like(~D[2026-10-01], ~T[18:00:00], [])

      assert "Thu, Oct 1 at 6:00 PM" in Post.lines(huddl, moment: :when_published, link: @link)
    end

    test "a full huddl still posts and says the waitlist is open" do
      huddl = huddl_like(~D[2026-10-01], ~T[18:00:00], max_attendees: 2, rsvp_count: 2)

      assert "Full, waitlist open" in Post.lines(huddl, moment: :hour_before, link: @link)
    end

    test "a blank opening line is left out" do
      huddl = huddl_like(~D[2026-10-01], ~T[18:00:00], event_type: :virtual)

      assert hd(Post.lines(huddl, moment: :when_published, opening_line: "  ", link: @link)) ==
               huddl.title
    end
  end

  describe "a new series" do
    test "names the pattern and where it starts, without a spots line" do
      huddl = huddl_like(~D[2026-10-01], ~T[18:00:00], title: "Hack night", max_attendees: 20)

      assert Post.lines(huddl,
               moment: :series,
               series: %{interval: 1, unit: :week},
               link: @link
             ) == [
               huddl.title,
               "Every Thursday at 6:00 PM, starting Thu, Oct 1",
               "123 Main St, Anytown, USA",
               @link
             ]
    end

    test "says every other week and the day of the month" do
      huddl = huddl_like(~D[2026-10-22], ~T[18:30:00], title: "Hack night", event_type: :virtual)
      lines = &Post.lines(huddl, moment: :series, series: &1, link: @link)

      assert "Every other Thursday at 6:30 PM, starting Thu, Oct 22" in lines.(%{
               interval: 2,
               unit: :week
             })

      assert "Monthly on the 22nd at 6:30 PM, starting Thu, Oct 22" in lines.(%{
               interval: 1,
               unit: :month
             })
    end
  end

  describe "follow-ups" do
    test "a cancelled huddl says it won't go ahead, without the opening line" do
      huddl = huddl_like(~D[2026-10-01], ~T[18:00:00], title: "Hack night", event_type: :virtual)

      assert Post.lines(huddl, moment: :cancelled, opening_line: "This week:", link: @link) ==
               ["Cancelled: Hack night on Thu, Oct 1 won't go ahead."]
    end

    test "a moved huddl gives the new time with the old one, and the link" do
      huddl = huddl_like(~D[2026-10-02], ~T[19:00:00], title: "Hack night", event_type: :virtual)
      was = ~U[2026-10-01 22:00:00Z]

      assert Post.lines(huddl, moment: :moved, previous_starts_at: was, link: @link) == [
               "New time: Hack night is now Fri, Oct 2 at 7:00 PM (was Thu, Oct 1 at 6:00 PM).",
               @link
             ]
    end
  end

  # A map shaped like a loaded huddl on that date, so pinned dates never have
  # to pass the create action's future-date check.
  defp huddl_like(date, time, attrs) do
    starts_at = date |> DateTime.new!(time, "America/New_York") |> DateTime.shift_zone!("Etc/UTC")

    Map.merge(
      %{
        title: "Elixir Night",
        starts_at: starts_at,
        time_zone: "America/New_York",
        event_type: :in_person,
        physical_location: "123 Main St, Anytown, USA",
        max_attendees: nil,
        rsvp_count: 1,
        waitlist_count: 0
      },
      Map.new(attrs)
    )
  end

  defp thursday_at_least_a_week_out do
    week_out = Date.add(eastern_today(), 7)
    Date.add(week_out, Integer.mod(4 - Date.day_of_week(week_out), 7))
  end

  # A real huddl on that date; `going:` is how many people are going, counting
  # the creator, whom creating it signs up.
  defp generated_huddl(date, time, opts) do
    {going, opts} = Keyword.pop(opts, :going, 1)
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

    huddl =
      generate(
        huddl(
          Keyword.merge([date: date, start_time: time, group_id: group.id, actor: owner], opts)
        )
      )

    for _ <- 2..going//1 do
      person = generate(user(role: :user))
      Ash.update!(huddl, %{}, action: :rsvp, actor: person, authorize?: false)
    end

    Ash.load!(huddl, [:rsvp_count, :waitlist_count], authorize?: false)
  end
end

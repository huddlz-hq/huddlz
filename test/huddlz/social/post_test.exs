defmodule Huddlz.Social.PostTest do
  use Huddlz.DataCase, async: true

  @moduletag :social_post

  import Huddlz.Generator

  alias Huddlz.Social.Post

  @link "https://huddlz.com/groups/elixir-nashville/huddlz/1"

  describe "text/2" do
    test "an in-person huddl with spots left, a week before" do
      huddl = huddl_at(~D[2026-10-01], ~T[18:00:00], max_attendees: 20, going: 8)

      assert Post.text(huddl, moment: :week_before, opening_line: "This week:", link: @link) ==
               """
               This week:
               #{huddl.title}
               Thu, Oct 1 at 6:00 PM
               123 Main St, Anytown, USA
               12 spots left
               #{@link}
               """
               |> String.trim_trailing()
    end

    test "day-of posts say today, an online huddl says so, and no cap means no spots line" do
      huddl = huddl_at(~D[2026-10-01], ~T[09:30:00], event_type: :virtual)

      assert Post.lines(huddl, moment: :morning_of, link: @link) ==
               [huddl.title, "Today at 9:30 AM", "Online", @link]
    end

    test "a full huddl still posts and says the waitlist is open" do
      huddl = huddl_at(~D[2026-10-01], ~T[18:00:00], max_attendees: 2, going: 2)

      assert "Full, waitlist open" in Post.lines(huddl, moment: :hour_before, link: @link)
    end

    test "a blank opening line is left out" do
      huddl = huddl_at(~D[2026-10-01], ~T[18:00:00], event_type: :virtual)

      assert hd(Post.lines(huddl, moment: :when_published, opening_line: "  ", link: @link)) ==
               huddl.title
    end
  end

  describe "a new series" do
    test "names the pattern and where it starts, without a spots line" do
      huddl = series_huddl(~N[2026-10-01 18:00:00], event_type: :in_person, max_attendees: 20)

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
      huddl = series_huddl(~N[2026-10-22 18:30:00], event_type: :virtual)
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

  # The first huddl of a series, as a plain map: the formatter reads no more.
  defp series_huddl(local, opts) do
    Map.merge(
      %{
        title: "Hack night",
        starts_at:
          local |> DateTime.from_naive!("America/New_York") |> DateTime.shift_zone!("Etc/UTC"),
        time_zone: "America/New_York",
        physical_location: "123 Main St, Anytown, USA"
      },
      Map.new(opts)
    )
  end

  # A huddl on that date; `going:` is how many people are going, counting the
  # creator, whom creating it signs up.
  defp huddl_at(date, time, opts) do
    {going, opts} = Keyword.pop(opts, :going, 1)
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

    defaults = [date: date, start_time: time, group_id: group.id, actor: owner]

    defaults =
      if opts[:event_type] == :virtual,
        do: Keyword.put(defaults, :virtual_link, "https://meet.example/huddl"),
        else: defaults

    huddl = generate(huddl(Keyword.merge(defaults, opts)))

    for _ <- 2..going//1 do
      person = generate(user(role: :user))
      Ash.update!(huddl, %{}, action: :rsvp, actor: person, authorize?: false)
    end

    Ash.load!(huddl, [:rsvp_count, :waitlist_count], authorize?: false)
  end
end

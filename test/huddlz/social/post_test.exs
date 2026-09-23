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

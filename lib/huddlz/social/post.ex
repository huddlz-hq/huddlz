defmodule Huddlz.Social.Post do
  @moduledoc """
  The words a social post carries. One fixed shape, no templating: the
  connection's opening line if it has one, the huddl's title, when it is
  (day-of posts say "Today"), where, how many spots are left when there is
  a cap, and the link. Scheduled posts and the schedule sheet's preview both
  come from here, so what the preview shows is what the place receives.
  """

  alias Huddlz.Communities.SocialConnection.Moment

  @day_of [:morning_of, :hour_before]

  @typedoc "What a post needs to know about a huddl; a loaded huddl or a map shaped like one."
  @type huddl :: %{
          required(:title) => String.t(),
          required(:starts_at) => DateTime.t(),
          required(:time_zone) => String.t(),
          required(:event_type) => :in_person | :virtual | :hybrid,
          optional(:physical_location) => String.t() | nil,
          optional(:max_attendees) => non_neg_integer() | nil,
          optional(:rsvp_count) => non_neg_integer(),
          optional(:waitlist_count) => non_neg_integer()
        }

  @type option ::
          {:moment, Moment.t()} | {:opening_line, String.t() | nil} | {:link, String.t()}

  @doc "The post as one message, a line per part."
  @spec text(huddl(), [option()]) :: String.t()
  def text(huddl, opts), do: huddl |> lines(opts) |> Enum.join("\n")

  @doc "The parts of the post in order, skipping any the huddl has no use for."
  @spec lines(huddl(), [option()]) :: [String.t()]
  def lines(huddl, opts) do
    [
      opts[:opening_line],
      huddl.title,
      when_line(huddl, opts[:moment]),
      where_line(huddl),
      spots_line(huddl),
      opts[:link]
    ]
    |> Enum.reject(&blank?/1)
  end

  defp when_line(huddl, moment) do
    local = DateTime.shift_zone!(huddl.starts_at, huddl.time_zone)
    time = Calendar.strftime(local, "%-I:%M %p")

    if moment in @day_of,
      do: "Today at #{time}",
      else: "#{Calendar.strftime(local, "%a, %b %-d")} at #{time}"
  end

  defp where_line(%{event_type: :virtual}), do: "Online"

  defp where_line(%{event_type: :hybrid, physical_location: place}) when is_binary(place),
    do: "#{place} & online"

  defp where_line(%{physical_location: place}) when is_binary(place), do: place
  defp where_line(_huddl), do: nil

  # Anyone can join the waitlist of a full huddl, so full always says so.
  defp spots_line(%{max_attendees: cap} = huddl) when is_integer(cap) do
    case cap - count(huddl, :rsvp_count) do
      left when left <= 0 -> "Full, waitlist open"
      1 -> "1 spot left"
      left -> "#{left} spots left"
    end
  end

  defp spots_line(_huddl), do: nil

  defp count(huddl, key) do
    case Map.get(huddl, key) do
      n when is_integer(n) -> n
      _not_loaded -> 0
    end
  end

  defp blank?(nil), do: true
  defp blank?(text) when is_binary(text), do: String.trim(text) == ""
end

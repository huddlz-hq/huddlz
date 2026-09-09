defmodule HuddlzWeb.OgImage do
  @moduledoc """
  Draws the link-preview card advertised as `og:image` for a huddl or group
  that has no cover picture.

  Chat apps and social sites fetch that picture when someone pastes a link,
  so this is the first thing many people see of a huddl or group. The card
  is an SVG on the app's dark tokens, rasterised to PNG through libvips.
  """

  alias HuddlzWeb.Components.Card

  @width 1200
  @height 630
  @title_chars_per_line 28
  @secondary_chars 72
  @version 1

  def width, do: @width
  def height, do: @height

  @doc "Renders a huddl's card as a PNG binary."
  def huddl_card(huddl), do: huddl |> huddl_svg() |> render_png()

  @doc "Renders a group's card as a PNG binary."
  def group_card(group), do: group |> group_svg() |> render_png()

  defp render_png(svg) do
    with {:ok, image} <- Image.from_binary(svg) do
      Image.write(image, :memory, suffix: ".png")
    end
  end

  @doc """
  A strong ETag for the card, derived from everything drawn on it, so a
  shared link keeps its cached preview until the huddl actually changes.
  """
  def etag(huddl) do
    fingerprint =
      {@version, huddl.title, huddl.starts_at, huddl.ends_at, huddl.time_zone, huddl.status,
       huddl.event_type, huddl.physical_location, to_string(huddl.group.name)}

    ~s("og-#{:erlang.phash2(fingerprint)}")
  end

  @doc """
  A strong ETag for a group's card, derived from everything drawn on it.
  """
  def group_etag(group) do
    fingerprint =
      {@version, :group, to_string(group.name), group.member_count, group.location,
       group.description && to_string(group.description)}

    ~s("og-#{:erlang.phash2(fingerprint)}")
  end

  @doc "A huddl's card as SVG markup."
  def huddl_svg(huddl) do
    group_name = to_string(huddl.group.name)

    card_svg(%{
      initials: Card.group_initials(group_name),
      eyebrow: eyebrow(huddl, group_name),
      eyebrow_colour: eyebrow_colour(huddl),
      title: huddl.title,
      detail: when_line(huddl),
      secondary: place_line(huddl)
    })
  end

  @doc "A group's card as SVG markup."
  def group_svg(group) do
    name = to_string(group.name)

    card_svg(%{
      initials: Card.group_initials(name),
      eyebrow: group_eyebrow(group),
      eyebrow_colour: "#35d6de",
      title: name,
      detail: group.location || "Meets online",
      secondary: description_line(group)
    })
  end

  # One anatomy for every card: the brand, the initials tile, an eyebrow, a
  # title of up to two lines, a detail line and an optional muted line.
  defp card_svg(card) do
    title_lines = wrap_title(card.title)
    title_top = if length(title_lines) == 1, do: 372, else: 336
    detail_top = title_top + 76 * length(title_lines) + 4

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}">
      <rect width="#{@width}" height="#{@height}" fill="#0b1112"/>
      <rect x="0" y="#{@height - 6}" width="#{@width}" height="6" fill="#18cbd4"/>
      <rect x="72" y="72" width="44" height="44" rx="12" fill="#18cbd4"/>
      <text x="94" y="103" text-anchor="middle" font-family="#{font()}" font-size="26" font-weight="700" fill="#05191b">h</text>
      <text x="132" y="103" font-family="#{font()}" font-size="30" font-weight="700" fill="#eef5f5">huddlz</text>
      <rect x="960" y="72" width="168" height="168" rx="24" fill="#10181a" stroke="#2c3a3d" stroke-width="2"/>
      <text x="1044" y="176" text-anchor="middle" font-family="#{font()}" font-size="56" font-weight="700" letter-spacing="1" fill="#35d6de">#{escape(card.initials)}</text>
      <text x="72" y="#{title_top - 60}" font-family="#{font()}" font-size="22" font-weight="600" letter-spacing="2" fill="#{card.eyebrow_colour}">#{escape(String.upcase(card.eyebrow))}</text>
    #{title_markup(title_lines, title_top)}
      <text x="72" y="#{detail_top}" font-family="#{font()}" font-size="30" font-weight="500" fill="#b3bfc1">#{escape(card.detail)}</text>
    #{secondary_markup(card.secondary, detail_top + 48)}
    </svg>
    """
  end

  defp title_markup(lines, top) do
    lines
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {line, index} ->
      ~s(  <text x="72" y="#{top + index * 76}" font-family="#{font()}" font-size="62" font-weight="700" letter-spacing="-1" fill="#eef5f5">#{escape(line)}</text>)
    end)
  end

  defp secondary_markup(nil, _y), do: ""

  defp secondary_markup(text, y) do
    ~s(  <text x="72" y="#{y}" font-family="#{font()}" font-size="28" fill="#7f8c8f">#{escape(text)}</text>)
  end

  defp font, do: "Inter, ui-sans-serif, system-ui, -apple-system, 'Segoe UI', sans-serif"

  defp eyebrow(%{status: :cancelled}, group_name), do: "#{group_name} · Cancelled"
  defp eyebrow(%{status: :in_progress}, group_name), do: "#{group_name} · Happening now"
  defp eyebrow(%{status: :completed}, group_name), do: "#{group_name} · Completed"
  defp eyebrow(%{event_type: :virtual}, group_name), do: "#{group_name} · Online"
  defp eyebrow(%{event_type: :hybrid}, group_name), do: "#{group_name} · Hybrid"
  defp eyebrow(_huddl, group_name), do: "#{group_name} · In person"

  defp eyebrow_colour(%{status: :cancelled}), do: "#e84fb4"
  defp eyebrow_colour(%{status: :completed}), do: "#7f8c8f"
  defp eyebrow_colour(_huddl), do: "#35d6de"

  defp group_eyebrow(%{member_count: 1}), do: "Group · 1 member"

  defp group_eyebrow(%{member_count: count}) when is_integer(count),
    do: "Group · #{count} members"

  defp group_eyebrow(_group), do: "Group"

  # The description runs on a single muted line, so keep the first sentence
  # or so and end a cut-off description with an ellipsis.
  defp description_line(%{description: description}) when not is_nil(description) do
    description
    |> to_string()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> case do
      "" ->
        nil

      text when byte_size(text) <= @secondary_chars ->
        text

      text ->
        String.slice(text, 0, @secondary_chars - 1) |> String.trim_trailing() |> Kernel.<>("…")
    end
  end

  defp description_line(_group), do: nil

  defp when_line(huddl) do
    starts_at = DateTime.shift_zone!(huddl.starts_at, huddl.time_zone)
    ends_at = huddl.ends_at && DateTime.shift_zone!(huddl.ends_at, huddl.time_zone)

    cond do
      ends_at && DateTime.to_date(ends_at) == DateTime.to_date(starts_at) ->
        "#{date(starts_at)} · #{time(starts_at)} – #{time(ends_at)} #{starts_at.zone_abbr}"

      ends_at ->
        "#{date(starts_at)} #{time(starts_at)} → #{date(ends_at)} #{time(ends_at)} #{starts_at.zone_abbr}"

      true ->
        "#{date(starts_at)} · #{time(starts_at)} #{starts_at.zone_abbr}"
    end
  end

  defp date(datetime), do: Calendar.strftime(datetime, "%a, %b %-d")
  defp time(datetime), do: Calendar.strftime(datetime, "%-I:%M %p")

  defp place_line(%{event_type: :hybrid, physical_location: place}) when is_binary(place),
    do: "#{place} · & online"

  defp place_line(%{event_type: :in_person, physical_location: place}) when is_binary(place),
    do: place

  defp place_line(%{event_type: :virtual}), do: "Online"
  defp place_line(_huddl), do: nil

  # SVG has no automatic wrapping: break the title into at most two lines of
  # roughly the width the card can hold, and end a cut-off title with an
  # ellipsis.
  def wrap_title(title) do
    title
    |> to_string()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.flat_map(&split_long_word/1)
    |> Enum.reduce([], fn word, lines ->
      case lines do
        [] ->
          [word]

        [line | rest] when byte_size(line) + 1 + byte_size(word) <= @title_chars_per_line ->
          [line <> " " <> word | rest]

        _ ->
          [word | lines]
      end
    end)
    |> Enum.reverse()
    |> case do
      [first, second | rest] when rest != [] ->
        [first, String.slice(second, 0, @title_chars_per_line - 1) <> "…"]

      lines ->
        lines
    end
  end

  defp split_long_word(word) when byte_size(word) <= 28, do: [word]

  defp split_long_word(word) do
    word
    |> String.graphemes()
    |> Enum.chunk_every(@title_chars_per_line)
    |> Enum.map(&Enum.join/1)
  end

  defp escape(text), do: text |> to_string() |> Plug.HTML.html_escape()
end

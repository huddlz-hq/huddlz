defmodule HuddlzWeb.OgImage do
  @moduledoc """
  Draws the link-preview card advertised as `og:image` for a huddl or group
  that has no cover picture, and the site card every other page shares.

  Chat apps and social sites fetch that picture when someone pastes a link,
  so this is the first thing many people see of a huddl or group. The card
  is an SVG on the app's dark tokens, rasterised to PNG through libvips.
  """

  alias HuddlzWeb.Components.Card

  @width 1200
  @height 630
  @title_chars_per_line 28
  @secondary_chars 72
  @version 2
  @mark_box 512
  @mark_radius 121.9048
  @mark_glyph "M221.0227 260.8751V368.7619H171.0435V120.4286H220.1228V228.9452H216.0361Q223.3661 205.6317 238.3061 192.8635Q253.2462 180.0952 276.8427 180.0952Q296.216 180.0952 310.646 188.5202Q325.076 196.9452 333.0377 212.6635Q340.9994 228.3818 340.9994 250.2486V368.7619H290.9435V258.9583Q290.9435 241.5982 281.9884 231.7264Q273.0333 221.8546 257.2232 221.8546Q246.6797 221.8546 238.488 226.473Q230.2962 231.0914 225.6595 239.7832Q221.0227 248.4749 221.0227 260.8751Z"

  def width, do: @width
  def height, do: @height

  @doc "Renders a huddl's card as a PNG binary."
  def huddl_card(huddl), do: huddl |> huddl_svg() |> render_png()

  @doc "Renders a group's card as a PNG binary."
  def group_card(group), do: group |> group_svg() |> render_png()

  @doc "Renders the site card, shared by pages with no picture of their own, as a PNG binary."
  def site_card, do: site_svg() |> render_png()

  @doc "Renders the brand mark at `size` pixels square as a PNG binary."
  def mark_png(size), do: size |> mark_svg() |> render_png()

  @doc """
  The brand mark as SVG markup at `size` pixels square: the accent rounded
  square with the site card's Inter 700 "h" converted to an outline, preserving
  its shape and placement without requiring a font at render time.
  See `priv/branding/README.md` for the source and license.
  `mix huddlz.icons` writes the favicon set from it.
  """
  def mark_svg(size) do
    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}" viewBox="0 0 #{@mark_box} #{@mark_box}">
    #{mark_markup(0, 0, @mark_box)}
    </svg>
    """
  end

  # The mark placed at `x`, `y` and `size` pixels square inside a larger
  # drawing. The cards and the favicon all draw it through here, so the
  # tile and the "h" stay one thing.
  defp mark_markup(x, y, size) do
    scale = size / @mark_box

    ~s|  <g transform="translate(#{x} #{y}) scale(#{scale})"><rect width="#{@mark_box}" height="#{@mark_box}" rx="#{@mark_radius}" fill="#18cbd4"/><path d="#{@mark_glyph}" fill="#05191b"/></g>|
  end

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

  @doc "A strong ETag for the site card; it only changes with this module."
  def site_etag, do: ~s("og-site-#{@version}")

  @doc """
  The site card as SVG markup: the mark, the wordmark and the tagline, on
  the same ground as the other cards.
  """
  def site_svg do
    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}">
      <rect width="#{@width}" height="#{@height}" fill="#0b1112"/>
      <rect x="0" y="#{@height - 6}" width="#{@width}" height="6" fill="#18cbd4"/>
    #{mark_markup(72, 182, 168)}
      <text x="288" y="306" font-family="#{font()}" font-size="112" font-weight="700" letter-spacing="-3" fill="#eef5f5">huddlz</text>
      <text x="72" y="428" font-family="#{font()}" font-size="36" font-weight="500" fill="#b3bfc1">Find and join local community gatherings.</text>
      <text x="72" y="486" font-family="#{font()}" font-size="28" fill="#7f8c8f">huddlz.com</text>
    </svg>
    """
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
    #{mark_markup(72, 72, 44)}
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

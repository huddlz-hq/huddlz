defmodule Huddlz.Notifications.Layout do
  @moduledoc """
  The one layout every outbound email wears, rendered as HTML and plain
  text from the same pieces so the two can never drift.

  A sender describes the email and gets a `Swoosh.Email` back:

      Layout.email(%{
        to: user.email,
        subject: "Tomorrow: \#{huddl.title}",
        kicker: "Reminder · tomorrow",
        title: "\#{huddl.title} starts tomorrow",
        paragraphs: [["Hi \#{name}, you're going to ", {:strong, huddl.title}, "."]],
        facts: Layout.huddl_facts(huddl),
        action: {"Open the huddl", url},
        aside: "The calendar event is attached.",
        footer: Footer.activity(user, :huddl_reminder_24h)
      })

  Pieces, in the order they render:

    * `kicker` — one short line above the title, optional.
    * `title` — the one heading.
    * `paragraphs` — each a string or a list of segments: a string,
      `{:strong, text}` or `{:link, text, url}`.
    * `facts` — `{label, value}` or `{label, value, sub}` rows, optional.
      Huddl emails use `huddl_facts/1` so they carry what the card carries.
    * `action` — `{label, url}`, at most one button, optional.
    * `aside` — a quiet paragraph under the button, optional.
    * `footer` — `%{reason: text, links: [{label, url}]}`, see
      `Huddlz.Notifications.Footer`.

  Every string is escaped here, so senders pass raw values. The HTML is
  one 600px table on the light theme colours with inline styles and a
  system font stack; there is no dark variant because client support for
  it is unreliable. The subject goes through `HeaderSafe`.
  """

  import Swoosh.Email

  alias Huddlz.Communities.Huddl
  alias Huddlz.Mailer
  alias Huddlz.Notifications.DateTimeFormatter
  alias Huddlz.Notifications.Senders.HeaderSafe

  @type segment :: String.t() | {:strong, String.t()} | {:link, String.t(), String.t()}
  @type paragraph :: String.t() | [segment()]
  @type fact :: {String.t(), String.t()} | {String.t(), String.t(), String.t() | nil}
  @type footer :: %{reason: String.t(), links: [{String.t(), String.t()}]}
  @type spec :: %{
          required(:title) => String.t(),
          optional(:kicker) => String.t() | nil,
          optional(:paragraphs) => [paragraph()],
          optional(:facts) => [fact()],
          optional(:action) => {String.t(), String.t()} | nil,
          optional(:aside) => paragraph() | nil,
          optional(:footer) => footer() | nil,
          optional(:preheader) => String.t() | nil
        }

  @font "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
  @bg "#f4f7f7"
  @panel "#ffffff"
  @panel2 "#eef3f3"
  @line "#dde5e6"
  @text "#0f1a1b"
  @soft "#3f4f52"
  @muted "#5c6b6e"
  @accent "#0b7c83"
  @ink "#0a6c72"
  @on_accent "#ffffff"

  @doc """
  Builds the `Swoosh.Email` for a spec that also carries `:to` and
  `:subject`. `from` is `Mailer.from/0`.
  """
  @spec email(map()) :: Swoosh.Email.t()
  def email(%{to: to, subject: subject} = spec) do
    {html, text} = render(spec)

    new()
    |> from(Mailer.from())
    |> to(to_string(to))
    |> subject(HeaderSafe.safe(subject))
    |> html_body(html)
    |> text_body(text)
  end

  @doc "Renders `{html, text}` for a spec."
  @spec render(spec()) :: {String.t(), String.t()}
  def render(spec) do
    {html(spec), text(spec)}
  end

  @doc """
  The facts a huddl email carries, the same three as the huddl card:
  when in the huddl's own time zone, where, and the group. Takes the
  `Huddl` row (with `group` loaded) or a notification payload.
  """
  @spec huddl_facts(Huddl.t() | map()) :: [fact()]
  def huddl_facts(%Huddl{} = huddl) do
    when_fact(huddl.starts_at, huddl.ends_at, huddl.time_zone) ++
      where_fact(huddl.physical_location, huddl.event_type) ++
      group_fact(huddl.group && huddl.group.name)
  end

  def huddl_facts(payload) when is_map(payload) do
    time_zone = DateTimeFormatter.time_zone_from_payload(payload)

    when_fact(parse_iso(payload["starts_at_iso"]), parse_iso(payload["ends_at_iso"]), time_zone) ++
      where_fact(payload["physical_location"], payload["event_type"]) ++
      group_fact(payload["group_name"])
  end

  # ── HTML ─────────────────────────────────────────────────────────

  defp html(spec) do
    title = esc(spec.title)

    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="light">
    <meta name="supported-color-schemes" content="light">
    <title>#{title}</title>
    </head>
    <body style="margin:0;padding:0;background-color:#{@bg};">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">#{esc(preheader(spec))}</div>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#{@bg};">
    <tr><td align="center" style="padding:24px 16px;">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:600px;max-width:100%;">
    <tr><td style="background-color:#{@panel};border:1px solid #{@line};border-radius:12px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="padding:20px 32px;border-bottom:1px solid #{@line};">
    #{brand_html()}
    </td></tr>
    <tr><td style="padding:28px 32px 32px;font-family:#{@font};">
    #{kicker_html(spec[:kicker])}<h1 style="margin:0 0 16px;font-family:#{@font};font-size:22px;font-weight:700;line-height:1.25;letter-spacing:-0.01em;color:#{@text};">#{title}</h1>
    #{paragraphs_html(spec[:paragraphs] || [])}#{facts_html(spec[:facts] || [])}#{action_html(spec[:action])}#{aside_html(spec[:aside])}
    </td></tr>
    </table>
    </td></tr>
    <tr><td style="padding:20px 32px 0;font-family:#{@font};font-size:12px;line-height:1.6;color:#{@muted};">
    #{footer_html(spec[:footer])}
    </td></tr>
    </table>
    </td></tr>
    </table>
    </body>
    </html>
    """
  end

  defp brand_html do
    """
    <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
    <td width="32" height="32" align="center" valign="middle" style="width:32px;height:32px;background-color:#{@accent};border-radius:8px;color:#{@on_accent};font-family:#{@font};font-size:17px;font-weight:700;line-height:32px;">h</td>
    <td style="padding-left:10px;font-family:#{@font};font-size:16px;font-weight:700;letter-spacing:-0.01em;color:#{@text};">huddlz</td>
    </tr></table>
    """
  end

  defp kicker_html(nil), do: ""
  defp kicker_html(""), do: ""

  defp kicker_html(kicker) do
    ~s(<p style="margin:0 0 8px;font-size:12px;font-weight:600;letter-spacing:0.06em;text-transform:uppercase;color:#{@muted};">#{esc(kicker)}</p>\n)
  end

  defp paragraphs_html(paragraphs) do
    Enum.map_join(paragraphs, "", fn paragraph ->
      ~s(<p style="margin:0 0 16px;font-size:15px;line-height:1.55;color:#{@soft};">#{segments_html(paragraph)}</p>\n)
    end)
  end

  defp segments_html(text) when is_binary(text), do: esc(text)

  defp segments_html(segments) when is_list(segments),
    do: Enum.map_join(segments, "", &segment_html/1)

  defp segment_html(text) when is_binary(text), do: esc(text)

  defp segment_html({:strong, text}),
    do: ~s(<strong style="font-weight:600;color:#{@text};">#{esc(text)}</strong>)

  defp segment_html({:link, text, url}),
    do:
      ~s(<a href="#{esc(url)}" style="color:#{@ink};text-decoration:underline;">#{esc(text)}</a>)

  defp facts_html([]), do: ""

  defp facts_html(facts) do
    last = length(facts) - 1

    rows =
      facts
      |> Enum.with_index()
      |> Enum.map_join("", fn {fact, index} ->
        {label, value, sub} = normalize_fact(fact)
        border = if index == last, do: "", else: "border-bottom:1px solid #{@line};"

        sub_html =
          if sub,
            do:
              ~s(<br><span style="font-size:13px;font-weight:400;color:#{@muted};">#{esc(sub)}</span>),
            else: ""

        """
        <tr>
        <td valign="top" width="64" style="width:64px;padding:12px 16px 12px 0;#{border}font-family:#{@font};font-size:12px;font-weight:600;letter-spacing:0.04em;text-transform:uppercase;color:#{@muted};">#{esc(label)}</td>
        <td valign="top" style="padding:12px 0;#{border}font-family:#{@font};font-size:15px;font-weight:600;line-height:1.4;color:#{@text};">#{esc(value)}#{sub_html}</td>
        </tr>
        """
      end)

    """
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 20px;background-color:#{@panel2};border-radius:10px;">
    <tr><td style="padding:4px 20px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    #{rows}</table>
    </td></tr>
    </table>
    """
  end

  defp action_html(nil), do: ""

  defp action_html({label, url}) do
    """
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:4px 0 16px;">
    <tr><td style="background-color:#{@accent};border-radius:8px;">
    <a href="#{esc(url)}" style="display:inline-block;padding:13px 22px;font-family:#{@font};font-size:15px;font-weight:700;color:#{@on_accent};text-decoration:none;">#{esc(label)}</a>
    </td></tr>
    </table>
    """
  end

  defp aside_html(nil), do: ""
  defp aside_html(""), do: ""

  defp aside_html(aside) do
    ~s(<p style="margin:0;font-size:13px;line-height:1.5;color:#{@muted};">#{segments_html(aside)}</p>\n)
  end

  defp footer_html(nil), do: ~s(<p style="margin:0;">huddlz · #{esc(support_address())}</p>)

  defp footer_html(%{reason: reason} = footer) do
    links =
      footer
      |> Map.get(:links, [])
      |> Enum.map_join(" · ", fn {label, url} ->
        ~s(<a href="#{esc(url)}" style="color:#{@ink};text-decoration:underline;">#{esc(label)}</a>)
      end)

    line = if links == "", do: esc(reason), else: "#{esc(reason)} #{links}."

    """
    <p style="margin:0 0 6px;">#{line}</p>
    <p style="margin:0;">huddlz · #{esc(support_address())}</p>
    """
  end

  # ── Plain text ───────────────────────────────────────────────────

  defp text(spec) do
    [
      "huddlz",
      "",
      kicker_text(spec[:kicker]),
      spec.title,
      "",
      paragraphs_text(spec[:paragraphs] || []),
      facts_text(spec[:facts] || []),
      action_text(spec[:action]),
      aside_text(spec[:aside]),
      "--",
      footer_text(spec[:footer])
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp kicker_text(nil), do: nil
  defp kicker_text(""), do: nil
  defp kicker_text(kicker), do: String.upcase(kicker)

  defp paragraphs_text(paragraphs) do
    Enum.map(paragraphs, fn paragraph -> [segments_text(paragraph), ""] end)
  end

  defp segments_text(text) when is_binary(text), do: text

  defp segments_text(segments) when is_list(segments),
    do: Enum.map_join(segments, "", &segment_text/1)

  defp segment_text(text) when is_binary(text), do: text
  defp segment_text({:strong, text}), do: text
  defp segment_text({:link, text, url}) when text == url, do: url
  defp segment_text({:link, text, url}), do: "#{text} (#{url})"

  defp facts_text([]), do: nil

  defp facts_text(facts) do
    facts = Enum.map(facts, &normalize_fact/1)
    width = facts |> Enum.map(fn {label, _, _} -> String.length(label) end) |> Enum.max()

    lines =
      Enum.map(facts, fn {label, value, sub} ->
        String.pad_trailing("#{label}:", width + 2) <> value <> if(sub, do: " (#{sub})", else: "")
      end)

    lines ++ [""]
  end

  defp action_text(nil), do: nil
  defp action_text({label, url}), do: ["#{label}: #{url}", ""]

  defp aside_text(nil), do: nil
  defp aside_text(""), do: nil
  defp aside_text(aside), do: [segments_text(aside), ""]

  defp footer_text(nil), do: "huddlz · #{support_address()}"

  defp footer_text(%{reason: reason} = footer) do
    links = footer |> Map.get(:links, []) |> Enum.map(fn {label, url} -> "#{label}: #{url}" end)
    [reason | links] ++ ["huddlz · #{support_address()}"]
  end

  # ── Facts helpers ────────────────────────────────────────────────

  defp when_fact(nil, _ends_at, _time_zone), do: []

  defp when_fact(%DateTime{} = starts_at, ends_at, time_zone) do
    [
      {"When", DateTimeFormatter.format_starts_at(starts_at, time_zone),
       duration(starts_at, ends_at)}
    ]
  end

  defp duration(%DateTime{} = starts_at, %DateTime{} = ends_at) do
    minutes = DateTime.diff(ends_at, starts_at, :minute)

    cond do
      minutes <= 0 -> nil
      minutes < 60 -> "#{minutes} minutes"
      rem(minutes, 60) == 0 -> plural(div(minutes, 60), "hour")
      true -> "#{plural(div(minutes, 60), "hour")} #{rem(minutes, 60)} minutes"
    end
  end

  defp duration(_, _), do: nil

  defp plural(1, word), do: "1 #{word}"
  defp plural(n, word), do: "#{n} #{word}s"

  defp where_fact(place, event_type) do
    virtual? = to_string(event_type) in ["virtual", "hybrid"]

    cond do
      present?(place) and virtual? -> [{"Where", place, "Also online"}]
      present?(place) -> [{"Where", place}]
      virtual? -> [{"Where", "Online"}]
      true -> []
    end
  end

  defp group_fact(name) do
    if present?(name), do: [{"Group", to_string(name)}], else: []
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value) and present?(to_string(value))

  defp parse_iso(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_iso(_), do: nil

  defp normalize_fact({label, value}), do: {to_string(label), to_string(value), nil}

  defp normalize_fact({label, value, sub}),
    do: {to_string(label), to_string(value), if(present?(sub), do: to_string(sub), else: nil)}

  defp preheader(spec) do
    case spec[:preheader] do
      nil -> spec.title
      text -> text
    end
  end

  defp support_address, do: elem(Mailer.from(), 1)

  # Escapes `& < > "`; apostrophes stay readable because every attribute
  # in the layout is double-quoted.
  defp esc(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace("&#39;", "'")
  end

  defp sentence(text) do
    case String.split(text, "", parts: 2, trim: true) do
      [first, rest] -> String.upcase(first) <> rest
      [first] -> String.upcase(first)
      [] -> ""
    end
  end

  @doc "Upcases the first character, for a title built from a lowercase fallback."
  def sentence_case(text), do: sentence(to_string(text))
end

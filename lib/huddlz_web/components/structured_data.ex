defmodule HuddlzWeb.StructuredData do
  @moduledoc """
  Public page JSON-LD, rendered inside the LiveView so navigation replaces it.
  A public canonical URL gates output, including for authenticated viewers.
  """
  use HuddlzWeb, :html

  alias Huddlz.Storage.{GroupImages, HuddlImages}
  alias HuddlzWeb.MetaHelpers

  attr :huddl, :any, required: true
  attr :url, :string, required: true

  def huddl(assigns) do
    assigns = assign(assigns, :data, huddl_data(assigns.huddl, assigns.url))

    ~H"""
    <.json_ld data={@data} />
    """
  end

  attr :group, :any, required: true
  attr :url, :string, required: true

  def group(assigns) do
    assigns = assign(assigns, :data, group_data(assigns.group, assigns.url))

    ~H"""
    <.json_ld data={@data} />
    """
  end

  defp group_data(_group, nil), do: nil

  defp group_data(group, public_url) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "@id" => public_url,
      "url" => public_url,
      "name" => group.name,
      "description" => group.description,
      "location" => if(group.location, do: %{"@type" => "Place", "name" => group.location}),
      "image" => MetaHelpers.image_url(group.current_image_url, GroupImages)
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp huddl_data(_huddl, nil), do: nil

  defp huddl_data(huddl, public_url) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Event",
      "@id" => public_url,
      "url" => public_url,
      "name" => huddl.title,
      "description" => huddl.description,
      "startDate" => local_date(huddl.starts_at, huddl.time_zone),
      "endDate" => local_date(huddl.ends_at, huddl.time_zone),
      "eventStatus" => "https://schema.org/EventScheduled",
      "eventAttendanceMode" => attendance_mode(huddl.event_type),
      "location" => location(huddl),
      "organizer" => %{
        "@type" => "Organization",
        "@id" => url(~p"/groups/#{huddl.group.slug}"),
        "url" => url(~p"/groups/#{huddl.group.slug}"),
        "name" => huddl.group.name
      },
      "image" => MetaHelpers.image_url(huddl.display_image_url, HuddlImages)
    }
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp local_date(datetime, time_zone) do
    datetime |> DateTime.shift_zone!(time_zone) |> DateTime.to_iso8601()
  end

  defp attendance_mode(:in_person), do: "https://schema.org/OfflineEventAttendanceMode"
  defp attendance_mode(:virtual), do: "https://schema.org/OnlineEventAttendanceMode"
  defp attendance_mode(:hybrid), do: "https://schema.org/MixedEventAttendanceMode"

  defp location(%{event_type: :virtual}), do: virtual_location()
  defp location(%{event_type: :in_person} = huddl), do: physical_location(huddl)

  defp location(%{event_type: :hybrid} = huddl),
    do: [physical_location(huddl), virtual_location()]

  # Join links require an RSVP and must never enter public metadata, even when
  # the current viewer can see them. The public page only identifies "Online".
  defp virtual_location, do: %{"@type" => "VirtualLocation", "name" => "Online"}

  defp physical_location(huddl) do
    %{
      "@type" => "Place",
      "address" => %{"@type" => "PostalAddress", "name" => huddl.physical_location}
    }
  end

  attr :data, :map, default: nil

  defp json_ld(assigns) do
    ~H"""
    <%!-- Inert JSON-LD data, not executable inline JavaScript. --%>
    <script :if={@data} id="public-structured-data" type="application/ld+json">
      <%= raw(encode(@data)) %>
    </script>
    """
  end

  # Escape HTML delimiters as well as JSON strings: even <!-- and <script>
  # inside a description must not change the HTML parser's script-data state.
  defp encode(data) do
    data
    |> Jason.encode!(escape: :html_safe)
    |> String.replace("<", "\\u003C")
    |> String.replace(">", "\\u003E")
    |> String.replace("&", "\\u0026")
  end
end

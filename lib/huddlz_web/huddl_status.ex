defmodule HuddlzWeb.HuddlStatus do
  @moduledoc """
  Central presentation vocabulary for a huddl's lifecycle-derived status.
  """

  @presentations %{
    draft: %{
      label: "Draft",
      variant: :muted,
      hero_class: "is-cancelled",
      eyebrow_class: "eyebrow-muted",
      banner_class: "muted",
      banner_text: "This draft is visible only to organizers"
    },
    upcoming: %{
      label: "Upcoming",
      variant: :default,
      hero_class: nil,
      eyebrow_class: nil,
      banner_class: nil,
      banner_text: nil
    },
    in_progress: %{
      label: "Happening now",
      variant: :warn,
      hero_class: nil,
      eyebrow_class: "eyebrow-warn",
      banner_class: nil,
      banner_text: nil
    },
    completed: %{
      label: "Completed",
      variant: :muted,
      hero_class: nil,
      eyebrow_class: "eyebrow-muted",
      banner_class: "muted",
      banner_text: "This huddl has ended"
    },
    cancelled: %{
      label: "Cancelled",
      variant: :magenta,
      hero_class: "is-cancelled",
      eyebrow_class: "eyebrow-magenta",
      banner_class: "magenta",
      banner_text: "This huddl was cancelled"
    }
  }

  def label(status), do: presentation(status).label
  def variant(status), do: presentation(status).variant
  def hero_class(status), do: presentation(status).hero_class
  def eyebrow_class(status), do: presentation(status).eyebrow_class
  def banner_class(status), do: presentation(status).banner_class
  def banner_text(status), do: presentation(status).banner_text

  def pill_class(status) do
    case variant(status) do
      :default -> nil
      variant -> to_string(variant)
    end
  end

  def contextual_override(:cancelled) do
    %{key: "cancelled", label: label(:cancelled), variant: variant(:cancelled), rank: 8}
  end

  def contextual_override(_status), do: nil

  defp presentation(status) do
    Map.get_lazy(@presentations, status, fn ->
      %{
        label: status |> to_string() |> String.capitalize(),
        variant: :default,
        hero_class: nil,
        eyebrow_class: nil,
        banner_class: nil,
        banner_text: nil
      }
    end)
  end
end

defmodule Huddlz.Communities.Huddl.RecurrenceHelper do
  @moduledoc """
  Shared logic for generating recurring huddlz from a template.
  """

  alias Huddlz.Communities.Huddl

  @doc """
  Recursively generates future huddlz based on the template's frequency
  and repeat_until date. Each new huddl copies the source huddl's properties
  and advances the start/end times by the appropriate interval.
  """
  def generate_huddlz_from_template(huddl_template, huddl) do
    interval_days = frequency_days(huddl_template.frequency)
    starts_at = DateTime.add(huddl.starts_at, interval_days, :day)
    ends_at = DateTime.add(huddl.ends_at, interval_days, :day)
    start_at_date = DateTime.to_date(starts_at)

    if Date.before?(start_at_date, huddl_template.repeat_until) do
      new_huddl =
        Ash.Changeset.for_create(Huddl, :create, %{
          starts_at: starts_at,
          ends_at: ends_at,
          event_type: huddl.event_type,
          title: huddl.title,
          description: huddl.description,
          physical_location: huddl.physical_location,
          is_private: huddl.is_private,
          thumbnail_url: huddl.thumbnail_url,
          creator_id: huddl.creator_id,
          group_id: huddl.group_id,
          huddl_template_id: huddl_template.id
        })
        |> Ash.create!(authorize?: false)

      generate_huddlz_from_template(huddl_template, new_huddl)
    end
  end

  defp frequency_days(:weekly), do: 7
  defp frequency_days(:monthly), do: 30
end

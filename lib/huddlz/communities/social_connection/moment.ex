defmodule Huddlz.Communities.SocialConnection.Moment do
  @moduledoc """
  One moment of a social schedule: when a social connection posts each
  huddl. A fixed list; the timing of each is the scheduled posts' concern.
  """

  use Ash.Type.Enum,
    values: [:when_published, :week_before, :day_before, :morning_of, :hour_before]

  def graphql_type(_), do: :social_moment

  @doc "The moment as the schedule lists it."
  def label(:when_published), do: "When published"
  def label(:week_before), do: "A week before"
  def label(:day_before), do: "The day before"
  def label(:morning_of), do: "The morning of"
  def label(:hour_before), do: "An hour before"

  @doc "The short form for a chip."
  def short(:when_published), do: "When published"
  def short(:week_before), do: "Week before"
  def short(:day_before), do: "Day before"
  def short(:morning_of), do: "Morning of"
  def short(:hour_before), do: "Hour before"

  @doc "What the schedule sheet says under the moment."
  def hint(:when_published), do: "As soon as a huddl goes public."
  def hint(:week_before), do: "Same time of day as the huddl starts."
  def hint(:day_before), do: "Same time of day as the huddl starts."
  def hint(:morning_of), do: "9:00 AM in the huddl's time zone."
  def hint(:hour_before), do: ""
end

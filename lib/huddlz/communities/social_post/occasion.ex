defmodule Huddlz.Communities.SocialPost.Occasion do
  @moduledoc """
  Why a social post goes out: one of the social schedule's moments, the one
  post announcing a new series, a follow-up saying a huddl that was already
  posted has been cancelled or moved, or an organizer posting it now.
  """

  alias Huddlz.Communities.SocialConnection.Moment

  use Ash.Type.Enum,
    values: Moment.values() ++ [:series, :cancelled, :moved, :now]

  def graphql_type(_), do: :social_post_occasion

  @follow_ups [:cancelled, :moved]

  @doc "The follow-ups, which go out whatever the schedule says."
  def follow_ups, do: @follow_ups

  @doc "The occasion as the Social tab lists it."
  def label(:series), do: "New series"
  def label(:cancelled), do: "Cancelled"
  def label(:moved), do: "New time"
  def label(:now), do: "Posted now"
  def label(moment), do: Moment.short(moment)
end

defmodule Huddlz.Accounts.LandingPreference do
  @moduledoc """
  Where a person lands after signing in: their agenda (`:agenda`), their
  groups' huddlz (`:groups`), or discover (`:discover`).

  Deliberately page-level rather than agenda-scope-level, so the choice can
  name `/discover` — the surface most likely to hold the huddl someone
  arrived for.
  """

  use Ash.Type.Enum, values: [:agenda, :groups, :discover]

  @doc "The path a landing preference resolves to."
  def path(:agenda), do: "/agenda"
  def path(:groups), do: "/agenda?scope=groups"
  def path(:discover), do: "/discover"
  def path(_), do: "/agenda"

  @doc "Human label for a landing preference, as a destination name."
  def label(:agenda), do: "Agenda"
  def label(:groups), do: "My groups"
  def label(:discover), do: "Discover"
  def label(_), do: "Agenda"

  @doc "What this landing page shows, for a line of help text."
  def hint(:agenda), do: "Huddlz you've RSVP'd to"
  def hint(:groups), do: "Everything your groups have scheduled"
  def hint(:discover), do: "Search every huddl near you"
  def hint(_), do: "Huddlz you've RSVP'd to"
end

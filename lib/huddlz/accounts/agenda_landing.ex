defmodule Huddlz.Accounts.AgendaLanding do
  @moduledoc """
  Which filter the agenda opens on for a person: everything their groups
  have scheduled (`:groups`), or only the huddlz they have RSVP'd to
  (`:mine`).

  This is a filter preference, not a destination: the agenda stays the one
  signed-in home, so the preference never changes which page a person
  lands on, only what that page opens showing.
  """

  use Ash.Type.Enum, values: [:groups, :mine]
end

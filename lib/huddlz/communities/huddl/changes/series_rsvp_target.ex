defmodule Huddlz.Communities.Huddl.Changes.SeriesRsvpTarget do
  @moduledoc """
  A recipient's series-summary destination and eligible calendar huddlz.
  """

  alias Huddlz.Communities.Huddl

  @enforce_keys [:user_id, :next_huddl, :calendar_huddlz]
  defstruct [:user_id, :next_huddl, :calendar_huddlz]

  @type t :: %__MODULE__{
          user_id: Ecto.UUID.t(),
          next_huddl: Huddl.t(),
          calendar_huddlz: [Huddl.t()]
        }
end

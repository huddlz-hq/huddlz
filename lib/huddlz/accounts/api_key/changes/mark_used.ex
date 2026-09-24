defmodule Huddlz.Accounts.ApiKey.Changes.MarkUsed do
  @moduledoc """
  Stamps `last_used_at` with the current time, unless the key's use was
  already noted within the last minute. The list shows use to the minute
  at best, so a busy client does not need a write on every request.
  """

  use Ash.Resource.Change

  @window_seconds 60

  @impl true
  def change(changeset, _opts, _context) do
    now = DateTime.utc_now()

    if recently_used?(changeset.data.last_used_at, now) do
      changeset
    else
      Ash.Changeset.force_change_attribute(changeset, :last_used_at, now)
    end
  end

  defp recently_used?(%DateTime{} = at, now), do: DateTime.diff(now, at) < @window_seconds
  defp recently_used?(nil, _now), do: false
end

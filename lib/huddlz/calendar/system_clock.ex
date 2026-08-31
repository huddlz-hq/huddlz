defmodule Huddlz.Calendar.SystemClock do
  @moduledoc false

  @behaviour Huddlz.Calendar.Clock

  @impl true
  def utc_now, do: DateTime.utc_now()
end

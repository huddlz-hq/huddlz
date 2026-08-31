defmodule Huddlz.Calendar.Clock do
  @moduledoc """
  Provides the current instant used to choose device-local Calendar ranges.
  """

  @callback utc_now() :: DateTime.t()

  @adapter Application.compile_env(
             :huddlz,
             [:calendar, :clock],
             Huddlz.Calendar.SystemClock
           )

  def utc_now, do: @adapter.utc_now()
end

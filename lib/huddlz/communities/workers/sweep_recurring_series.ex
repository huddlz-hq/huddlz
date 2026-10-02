defmodule Huddlz.Communities.Workers.SweepRecurringSeries do
  @moduledoc """
  Enqueues maintenance for every recurring series that is still generating.

  This is the only thing keeping a boundless series alive, so it is
  deliberately self-healing: each run re-derives the full set of eligible
  series from the database rather than relying on per-series scheduling, which
  could be dropped once and never noticed again. A missed run costs a day, and
  the next run catches up.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Communities.Workers.MaintainRecurringSeries

  @impl Oban.Worker
  def perform(_job) do
    HuddlTemplate
    |> Ash.Query.for_read(:due_for_maintenance)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn template ->
      %{huddl_template_id: template.id}
      |> MaintainRecurringSeries.new()
      |> Oban.insert!()
    end)

    :ok
  end
end

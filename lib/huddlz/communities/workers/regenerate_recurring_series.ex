defmodule Huddlz.Communities.Workers.RegenerateRecurringSeries do
  @moduledoc """
  Generates the future instances of a recurring huddl series off the request
  path. Enqueued when a recurring huddl is created. Idempotent: a retry clears
  and rebuilds the future instances rather than duplicating them, so a partial
  failure mid-generation is safe to retry.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Communities.HuddlTemplate

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"huddl_id" => huddl_id}}) do
    huddl =
      Huddl
      |> Ash.Query.for_read(:get_for_recurrence, %{id: huddl_id})
      |> Ash.Query.load(:huddl_template)
      |> Ash.read_one!(authorize?: false)

    case huddl do
      %Huddl{huddl_template: %HuddlTemplate{} = template} ->
        RecurrenceHelper.regenerate_series(huddl, template)

      _ ->
        # The huddl was deleted before the job ran, or it isn't part of a
        # series — nothing to generate.
        :ok
    end

    :ok
  end
end

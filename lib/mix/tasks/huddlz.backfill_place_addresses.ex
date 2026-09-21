defmodule Mix.Tasks.Huddlz.BackfillPlaceAddresses do
  use Mix.Task

  @shortdoc "Resolve older saved locations to full addresses and place ids"

  @moduledoc """
  Reverse geocodes saved locations that have no place id, replacing their
  ambiguous street-and-city address with a full address so map links open the
  exact place. Needs the Google Maps API key.

  ## Usage

      mix huddlz.backfill_place_addresses
      mix huddlz.backfill_place_addresses --dry-run

  With `--dry-run` nothing is written.
  """

  alias Huddlz.Communities.PlaceBackfill

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: [dry_run: :boolean])
    Mix.Task.run("app.start")

    %{resolved: resolved, skipped: skipped} =
      PlaceBackfill.run(dry_run: Keyword.get(opts, :dry_run, false))

    verb = if opts[:dry_run], do: "Would resolve", else: "Resolved"
    Mix.shell().info("#{verb} #{resolved} saved locations; #{skipped} could not be resolved.")
  end
end

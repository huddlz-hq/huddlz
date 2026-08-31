defmodule Mix.Tasks.TzWorldData do
  use Mix.Task

  @shortdoc "Download TzWorld data (CI-safe wrapper around tz_world.update)"

  @moduledoc """
  Runs `mix tz_world.update`, but first force-loads the `:inets` helper
  modules that `:httpc` only calls lazily.

  ## Why this wrapper exists

  `TzWorld.Downloader` fetches the timezone-boundary release list from the
  GitHub API with the built-in `:httpc` client. GitHub now returns that
  response with `Transfer-Encoding: chunked`, so `:httpc` calls
  `:http_chunk.decode/3` to reassemble the body.

  In some environments (observed on CI with OTP 29, `erlef/setup-beam`) the
  on-demand code load for `:http_chunk` fails with `:undef` inside the
  `:httpc` handler process. `httpc_handler` only rescues `throw:{:error, _}`,
  so the `:undef` crashes the handler and `:httpc.request/4` returns
  `{:error, {:shutdown, {{:error, :undef}, _stacktrace}}}` -- a shape
  `TzWorld.Downloader.get_with_headers/2` does not match, producing a
  `CaseClauseError` and failing the task.

  Pre-loading `:http_chunk` here removes the lazy load from the handler's
  hot path. This mirrors tz_world's own `Code.ensure_loaded(:ssl_cipher)`
  workaround in `Mix.Tasks.TzWorld.Update`.
  """

  @impl Mix.Task
  def run(args) do
    Enum.each([:http_chunk], &Code.ensure_loaded!/1)
    Mix.Task.run("tz_world.update", args)
  end
end

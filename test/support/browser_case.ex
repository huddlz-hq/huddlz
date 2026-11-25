defmodule HuddlzWeb.BrowserCase do
  @moduledoc """
  The case template of the browser scenarios' test modules, which Cucumber
  generates (see `test/browser/browser_features_test.exs`).
  """

  use ExUnit.CaseTemplate

  using opts do
    quote do
      use Playwright.Test, unquote(opts)
    end
  end

  # Runs before Playwright.Test's setup, so the sandbox owner stops after the
  # scenario's browser contexts have closed.
  setup tags do
    Huddlz.DataCase.setup_sandbox(tags)
    :ok
  end
end

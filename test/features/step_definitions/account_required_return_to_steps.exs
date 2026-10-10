defmodule AccountRequiredReturnToSteps do
  @moduledoc """
  Steps for signing in after a page that needs an account sent the person to
  the sign-in page.
  """
  use Cucumber.StepDefinition

  import PhoenixTest

  step "I should be back at {string}", %{args: [address], session: session} = context do
    uri = URI.parse(address)
    query_params = URI.decode_query(uri.query || "")

    assert_path(session, uri.path, query_params: query_params)
    context
  end
end

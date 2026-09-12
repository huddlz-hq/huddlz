defmodule WwwRedirectSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions
  import Phoenix.ConnTest

  @endpoint HuddlzWeb.Endpoint

  step "a visitor requests {string}", %{args: [url]} = context do
    {:ok, Map.put(context, :redirect_response, get(build_conn(), url))}
  end

  step "they are permanently redirected to {string}", %{args: [url]} = context do
    assert redirected_to(context.redirect_response, 301) == url
    :ok
  end
end

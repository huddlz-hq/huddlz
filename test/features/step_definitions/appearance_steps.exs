defmodule AppearanceSteps do
  @moduledoc """
  Steps for the appearance (theme) preference. The theme is applied as a
  `data-theme` attribute on the `<html>` element by the root layout, which
  PhoenixTest's LiveView session does not render, so these steps fetch a
  fresh page over the session's connection and inspect the full document.
  """

  use Cucumber.StepDefinition
  import ExUnit.Assertions
  import Phoenix.ConnTest

  @endpoint HuddlzWeb.Endpoint

  step "the page should follow the device appearance", context do
    assert html_theme(context) == nil
    {:ok, context}
  end

  step "the page should use the {string} appearance", %{args: [theme]} = context do
    assert html_theme(context) == theme
    {:ok, context}
  end

  defp html_theme(context) do
    session = context[:session] || context[:conn]

    conn =
      case session do
        %Plug.Conn{} = conn -> conn
        %{conn: %Plug.Conn{} = conn} -> conn
      end

    html =
      conn
      |> recycle()
      |> get("/discover")
      |> html_response(200)

    case html |> Floki.parse_document!() |> Floki.attribute("html", "data-theme") do
      [] -> nil
      [theme] -> theme
    end
  end
end

defmodule HuddlzWeb.DevDesignHTMLTest do
  use ExUnit.Case, async: true

  alias HuddlzWeb.DevDesignHTML
  alias Phoenix.HTML.Safe

  test "clickthrough surfaces use huddl product terminology" do
    settings_html = render_surface(&DevDesignHTML.clickthrough_settings/1, "settings")
    help_html = render_surface(&DevDesignHTML.clickthrough_help/1, "help")
    huddl_html = render_surface(&DevDesignHTML.clickthrough_huddl/1, "huddl")

    assert settings_html =~ "Critical account and huddl updates"
    assert help_html =~ "A huddl can be a meetup, workshop, social, or anything else."
    assert help_html =~ "huddlz worth knowing about"
    assert huddl_html =~ ~s(A small "huddlz" app)

    refute settings_html =~ "account and event updates"
    refute help_html =~ "word for an event"
    refute help_html =~ "events worth knowing about"
    refute huddl_html =~ ~s(A small "events" app)
  end

  defp render_surface(surface, active) do
    %{active: active, query: "", signed_in: true}
    |> surface.()
    |> Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end

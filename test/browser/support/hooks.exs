defmodule BrowserHooks do
  use Cucumber.Hooks

  before_scenario context do
    # Serial suite: HTTP and LiveView processes share these Mox stubs.
    Mox.set_mox_global()
    Mox.stub_with(Huddlz.MockGeocoding, Huddlz.GeocodingStub)
    Mox.stub_with(Huddlz.MockPlaces, Huddlz.PlacesStub)
    Mox.stub_with(Huddlz.MockStorage, Huddlz.Storage.Local)

    context =
      cond do
        Map.get(context, :clipboard_browser) ->
          Map.put(context, :browser_context_opts,
            permissions: ["clipboard-read", "clipboard-write"]
          )

        Map.get(context, :mobile) ->
          Map.put(context, :browser_context_opts, viewport: %{width: 320, height: 720})

        # A short desktop window: wide enough for the sidebar, too short for it.
        Map.get(context, :short) ->
          Map.put(context, :browser_context_opts, viewport: %{width: 1280, height: 520})

        true ->
          context
      end

    # ExUnit runs `on_exit` callbacks in reverse: the sandbox owner, registered
    # first, stops last, after the scenario's browser contexts have closed.
    Huddlz.DataCase.setup_sandbox(context)

    # A stop-gap until Cucumber can add a case template's `use` to the modules
    # it generates. They only `use ExUnit.Case`, so run Playwright.Test's
    # per-test setup here. Without its `test`, Playwright.Test never learns a
    # scenario's result, so every scenario's screenshot is named as failed.
    Playwright.Test.__setup__(context)

    session =
      :playwright
      |> Fluffy.start_session(browser_context: Map.get(context, :browser_context_opts, []))
      |> answer_external_requests_locally()

    Map.put(context, :session, session)
  end

  @inter_url "https://fonts.gstatic.com/s/inter/v20/inter-latin.woff2"

  # Inter's Latin subset as Google Fonts serves it: one variable font for every
  # weight the layout links.
  @inter_css """
  @font-face {
    font-family: 'Inter';
    font-style: normal;
    font-weight: 300 700;
    font-display: swap;
    src: url(#{@inter_url}) format('woff2');
    unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
  }
  """

  # Pages link Google Fonts and embed Google Maps. A slow reply from Google
  # holds the load event that visit waits for, so every external request is
  # answered locally: Inter from a fixture, so layouts measure as they do in
  # production, and anything else with an empty response.
  defp answer_external_requests_locally(session) do
    # Playwright resolves a bare "https://**" to "https://**/", which only
    # matches URLs ending in a slash.
    Fluffy.Playwright.route(session, "https://*/**", fn route, request ->
      Playwright.Route.fulfill!(route, response(Playwright.Request.url(request)))
    end)
  end

  defp response("https://fonts.googleapis.com/" <> _),
    do: [content_type: "text/css", body: @inter_css]

  defp response(@inter_url),
    do: [content_type: "font/woff2", path: "test/fixtures/fonts/inter-latin.woff2"]

  defp response(_url), do: [content_type: "text/plain"]
end

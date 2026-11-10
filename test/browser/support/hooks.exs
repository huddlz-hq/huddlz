defmodule BrowserHooks do
  use Cucumber.Hooks

  alias PhoenixTest.Playwright.Case, as: BrowserCase

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
            timezone_id: "America/New_York",
            permissions: ["clipboard-read", "clipboard-write"]
          )

        Map.get(context, :mobile) ->
          Map.put(context, :browser_context_opts,
            timezone_id: "America/New_York",
            viewport: %{width: 320, height: 720}
          )

        # A short desktop window: wide enough for the sidebar, too short for it.
        Map.get(context, :short) ->
          Map.put(context, :browser_context_opts,
            timezone_id: "America/New_York",
            viewport: %{width: 1280, height: 520}
          )

        true ->
          context
      end

    context = Map.merge(context, Map.new(BrowserCase.do_setup_all(context)))
    # Cucumber's generated module atoms lack the Elixir prefix expected by
    # the adapter's artifact filenames. Keep the original scenario name.
    driver_context = Map.put(context, :module, __MODULE__)
    context = Map.merge(context, Map.new(BrowserCase.do_setup(driver_context)))
    answer_external_requests_locally(context.conn)
    context
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
  defp answer_external_requests_locally(conn) do
    {:ok, _} =
      PlaywrightEx.BrowserContext.route(
        conn.context_id,
        # Playwright resolves a bare "https://**" to "https://**/", which only
        # matches URLs ending in a slash.
        "https://*/**",
        fn route, request ->
          {:ok, _} = PlaywrightEx.Route.fulfill(route, response(request.url))
        end,
        timeout: 5_000
      )
  end

  defp response("https://fonts.googleapis.com/" <> _),
    do: [content_type: "text/css", body: @inter_css]

  defp response(@inter_url),
    do: [content_type: "font/woff2", path: "test/fixtures/fonts/inter-latin.woff2"]

  defp response(_url), do: [content_type: "text/plain"]
end

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

  # Pages link Google Fonts and embed Google Maps. A slow reply from Google
  # holds the load event that visit waits for, so every external request gets
  # an empty local response and pages render with the fallback font.
  defp answer_external_requests_locally(conn) do
    {:ok, _} =
      PlaywrightEx.BrowserContext.route(
        conn.context_id,
        # Playwright resolves a bare "https://**" to "https://**/", which only
        # matches URLs ending in a slash.
        "https://*/**",
        fn route, request ->
          {:ok, _} = PlaywrightEx.Route.fulfill(route, content_type: content_type(request.url))
        end,
        timeout: 5_000
      )
  end

  defp content_type("https://fonts.googleapis.com/" <> _), do: "text/css"
  defp content_type(_url), do: "text/plain"
end

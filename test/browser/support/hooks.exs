defmodule BrowserPrototypeHooks do
  use Cucumber.Hooks

  alias PhoenixTest.Playwright.Case, as: BrowserCase

  before_scenario context do
    # Serial prototype only: HTTP and LiveView processes share these Mox stubs.
    Mox.set_mox_global()
    Mox.stub_with(Huddlz.MockGeocoding, Huddlz.GeocodingStub)
    Mox.stub_with(Huddlz.MockPlaces, Huddlz.PlacesStub)

    context = Map.merge(context, Map.new(BrowserCase.do_setup_all(context)))
    # Cucumber's generated module atoms lack the Elixir prefix expected by
    # the adapter's artifact filenames. Keep the original scenario name.
    driver_context = Map.put(context, :module, __MODULE__)
    Map.merge(context, Map.new(BrowserCase.do_setup(driver_context)))
  end
end

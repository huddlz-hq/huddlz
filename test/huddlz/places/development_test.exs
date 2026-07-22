defmodule Huddlz.Places.DevelopmentTest do
  use ExUnit.Case, async: false

  alias Huddlz.Places.Development
  alias Huddlz.Places.Google

  setup do
    google_maps_config = Application.get_env(:huddlz, :google_maps)

    on_exit(fn ->
      Application.put_env(:huddlz, :google_maps, google_maps_config)
    end)

    :ok
  end

  test "uses preset locations when the Google Maps API key is absent" do
    Application.put_env(:huddlz, :google_maps, api_key: nil)

    assert {:ok, suggestions} = Development.autocomplete("anything", "token", [])
    assert length(suggestions) == 7
  end

  test "uses Google Places when the Google Maps API key is configured" do
    Application.put_env(:huddlz, :google_maps, api_key: "configured-key")

    Req.Test.stub(Google, fn conn ->
      assert Plug.Conn.get_req_header(conn, "x-goog-api-key") == ["configured-key"]
      Req.Test.json(conn, %{"suggestions" => []})
    end)

    assert {:ok, []} = Development.autocomplete("Austin", "token", [])
  end
end

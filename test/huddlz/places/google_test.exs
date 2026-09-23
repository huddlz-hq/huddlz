defmodule Huddlz.Places.GoogleTest do
  use ExUnit.Case, async: true

  alias Huddlz.Places.Google

  describe "autocomplete/3" do
    test "prefers nearby address matches when a search location is supplied" do
      Req.Test.stub(Google, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        assert request["locationBias"] == %{
                 "circle" => %{
                   "center" => %{"latitude" => 29.9012, "longitude" => -81.3124},
                   "radius" => 50_000.0
                 }
               }

        refute Map.has_key?(request, "locationRestriction")
        Req.Test.json(conn, %{"suggestions" => []})
      end)

      assert {:ok, []} =
               Google.autocomplete("222 W King", "session-token",
                 types: [],
                 location_bias: %{latitude: 29.9012, longitude: -81.3124}
               )
    end

    test "searches normally without a valid search location" do
      Req.Test.stub(Google, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)
        refute Map.has_key?(request, "locationBias")
        Req.Test.json(conn, %{"suggestions" => []})
      end)

      for bias <- [nil, %{latitude: nil, longitude: nil}, %{latitude: 91, longitude: 0}] do
        assert {:ok, []} = Google.autocomplete("222 W King", "token", location_bias: bias)
      end
    end

    test "returns parsed suggestions" do
      Req.Test.stub(Google, fn conn ->
        Req.Test.json(conn, %{
          "suggestions" => [
            %{
              "placePrediction" => %{
                "placeId" => "place-123",
                "text" => %{"text" => "Austin, TX, USA"},
                "structuredFormat" => %{
                  "mainText" => %{"text" => "Austin"},
                  "secondaryText" => %{"text" => "TX, USA"}
                }
              }
            }
          ]
        })
      end)

      assert {:ok, [suggestion]} = Google.autocomplete("Austin", "session-token", [])
      assert suggestion.place_id == "place-123"
      assert suggestion.main_text == "Austin"
      assert suggestion.display_text == "Austin, TX, USA"
    end

    test "returns request_failed without retrying when the request times out" do
      test_pid = self()

      Req.Test.stub(Google, fn conn ->
        send(test_pid, :request_attempted)
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, %Req.TransportError{reason: :timeout}}} =
               Google.autocomplete("Austin", "session-token", [])

      assert_received :request_attempted
      refute_received :request_attempted
    end
  end

  describe "place_details/2" do
    test "returns coordinates and time zone" do
      Req.Test.stub(Google, fn conn ->
        Req.Test.json(conn, %{
          "location" => %{"latitude" => 30.2672, "longitude" => -97.7431},
          "timeZone" => %{"id" => "America/Chicago"}
        })
      end)

      assert {:ok, %{latitude: 30.2672, longitude: -97.7431, time_zone: "America/Chicago"}} =
               Google.place_details("place-123", "session-token")
    end

    test "returns the formatted address so a venue or street resolves to a full address" do
      Req.Test.stub(Google, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        [field_mask] = Plug.Conn.get_req_header(conn, "x-goog-fieldmask")
        assert "formattedAddress" in String.split(field_mask, ",")

        Req.Test.json(conn, %{
          "formattedAddress" => "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA",
          "location" => %{"latitude" => 30.1712, "longitude" => -81.6021},
          "timeZone" => %{"id" => "America/New_York"}
        })
      end)

      assert {:ok, %{formatted_address: "9801 Old St Augustine Rd, Jacksonville, FL 32257, USA"}} =
               Google.place_details("place-123", "session-token")
    end

    test "omits the formatted address when Google does not return one" do
      Req.Test.stub(Google, fn conn ->
        Req.Test.json(conn, %{
          "location" => %{"latitude" => 30.2672, "longitude" => -97.7431},
          "timeZone" => %{"id" => "America/Chicago"}
        })
      end)

      assert {:ok, %{formatted_address: nil}} = Google.place_details("place-123", "session-token")
    end

    test "returns request_failed without retrying when the request times out" do
      test_pid = self()

      Req.Test.stub(Google, fn conn ->
        send(test_pid, :request_attempted)
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, %Req.TransportError{reason: :timeout}}} =
               Google.place_details("place-123", "session-token")

      assert_received :request_attempted
      refute_received :request_attempted
    end
  end

  describe "redirect handling" do
    test "place_details does not follow a cross-host redirect" do
      test_pid = self()

      Req.Test.stub(Google, fn conn ->
        send(test_pid, {:requested_host, conn.host})

        conn
        |> Plug.Conn.put_resp_header("location", "https://evil.example.com/steal")
        |> Plug.Conn.resp(302, "")
      end)

      # With redirect: false the 3xx is surfaced as-is rather than followed.
      assert {:error, {:api_error, 302, _}} =
               Google.place_details("place-123", "session-token")

      # The Places host was contacted exactly once and the redirect target was
      # never requested — so the X-Goog-Api-Key header never left Google's domain.
      assert_received {:requested_host, "places.googleapis.com"}
      refute_received {:requested_host, "evil.example.com"}
    end

    test "autocomplete does not follow a cross-host redirect" do
      test_pid = self()

      Req.Test.stub(Google, fn conn ->
        send(test_pid, {:requested_host, conn.host})

        conn
        |> Plug.Conn.put_resp_header("location", "https://evil.example.com/steal")
        |> Plug.Conn.resp(302, "")
      end)

      assert {:error, {:api_error, 302, _}} =
               Google.autocomplete("Austin", "session-token", [])

      assert_received {:requested_host, "places.googleapis.com"}
      refute_received {:requested_host, "evil.example.com"}
    end
  end
end

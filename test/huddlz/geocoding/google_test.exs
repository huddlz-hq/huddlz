defmodule Huddlz.Geocoding.GoogleTest do
  use ExUnit.Case, async: true

  alias Huddlz.Geocoding.Google

  describe "geocode/1 result type handling" do
    test "geocodes street addresses (street_address type)" do
      Req.Test.stub(Google, fn conn ->
        Req.Test.json(conn, %{
          "status" => "OK",
          "results" => [
            %{
              "types" => ["street_address"],
              "geometry" => %{
                "location" => %{"lat" => 30.0325, "lng" => -81.4010}
              }
            }
          ]
        })
      end)

      assert {:ok, %{latitude: 30.0325, longitude: -81.4010}} =
               Google.geocode("324 Los Caminos St, St Augustine, FL")
    end

    test "geocodes premises (premise type)" do
      Req.Test.stub(Google, fn conn ->
        Req.Test.json(conn, %{
          "status" => "OK",
          "results" => [
            %{
              "types" => ["premise", "street_address"],
              "geometry" => %{
                "location" => %{"lat" => 29.9012, "lng" => -81.3124}
              }
            }
          ]
        })
      end)

      assert {:ok, %{latitude: 29.9012, longitude: -81.3124}} =
               Google.geocode("100 King St, St Augustine, FL")
    end

    test "geocodes routes (route type)" do
      Req.Test.stub(Google, fn conn ->
        Req.Test.json(conn, %{
          "status" => "OK",
          "results" => [
            %{
              "types" => ["route"],
              "geometry" => %{
                "location" => %{"lat" => 30.1234, "lng" => -81.5678}
              }
            }
          ]
        })
      end)

      assert {:ok, %{latitude: 30.1234, longitude: -81.5678}} =
               Google.geocode("Main Street, St Augustine, FL")
    end

    test "geocodes localities (city-level)" do
      Req.Test.stub(Google, fn conn ->
        Req.Test.json(conn, %{
          "status" => "OK",
          "results" => [
            %{
              "types" => ["locality", "political"],
              "geometry" => %{
                "location" => %{"lat" => 29.8946, "lng" => -81.3145}
              }
            }
          ]
        })
      end)

      assert {:ok, %{latitude: 29.8946, longitude: -81.3145}} =
               Google.geocode("St Augustine, FL")
    end

    test "rejects unrecognized result types" do
      Req.Test.stub(Google, fn conn ->
        Req.Test.json(conn, %{
          "status" => "OK",
          "results" => [
            %{
              "types" => ["country", "political"],
              "geometry" => %{
                "location" => %{"lat" => 37.0902, "lng" => -95.7129}
              }
            }
          ]
        })
      end)

      assert {:error, :not_found} = Google.geocode("United States")
    end

    test "handles ZERO_RESULTS response" do
      Req.Test.stub(Google, fn conn ->
        Req.Test.json(conn, %{
          "status" => "ZERO_RESULTS",
          "results" => []
        })
      end)

      assert {:error, :not_found} = Google.geocode("xyznonexistent12345")
    end

    test "handles API errors" do
      Req.Test.stub(Google, fn conn ->
        Req.Test.json(conn, %{
          "status" => "REQUEST_DENIED",
          "error_message" => "API key invalid"
        })
      end)

      assert {:error, {:api_error, "REQUEST_DENIED"}} = Google.geocode("Austin, TX")
    end

    test "rejects empty address" do
      assert {:error, :invalid_address} = Google.geocode("")
    end

    test "rejects whitespace-only address" do
      assert {:error, :invalid_address} = Google.geocode("   ")
    end

    test "rejects non-string input" do
      assert {:error, :invalid_address} = Google.geocode(nil)
      assert {:error, :invalid_address} = Google.geocode(123)
    end
  end
end

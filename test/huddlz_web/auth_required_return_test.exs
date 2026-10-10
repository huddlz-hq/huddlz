defmodule HuddlzWeb.AuthRequiredReturnTest do
  use HuddlzWeb.ConnCase, async: true
  alias Plug.Conn.Query

  test "account and admin guards retain static and dynamic destinations before loading private data",
       %{conn: conn} do
    for path <- [
          "/agenda",
          "/groups",
          "/calendar/week",
          "/calendar/month",
          "/notifications",
          "/notifications/00000000-0000-0000-0000-000000000001/open",
          "/profile",
          "/profile/notifications",
          "/profile/api-keys",
          "/admin",
          "/admin/users",
          "/admin/reports",
          "/organize",
          "/organize/return-group/social?filter%5Bname%5D=Elixir%2FPhoenix",
          "/groups/return-group/edit",
          "/groups/return-group/locations/new",
          "/groups/return-group/huddlz/00000000-0000-0000-0000-000000000001/edit"
        ] do
      redirect = conn |> get(path) |> redirected_to()
      uri = URI.parse(redirect)
      assert uri.path == "/sign-in"
      assert is_binary(uri.query), "Lost return for #{path}: #{redirect}"
      destination = Query.decode(uri.query)["return_to"] |> URI.parse()
      expected = URI.parse(path)
      assert destination.path == expected.path

      assert Query.decode(destination.query || "") ==
               Query.decode(expected.query || "")
    end
  end
end

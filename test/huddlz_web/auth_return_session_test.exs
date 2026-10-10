defmodule HuddlzWeb.AuthReturnSessionTest do
  use HuddlzWeb.ConnCase, async: true

  alias HuddlzWeb.AuthReturnSession

  test "a browser remembers the explicit destination through a reset email page", %{conn: conn} do
    conn = get(conn, "/sign-in?" <> URI.encode_query(return_to: "/discover?q=Elixir%2FPhoenix"))
    assert AuthReturnSession.destination(get_session(conn)) == "/discover?q=Elixir%2FPhoenix"
    conn = conn |> recycle() |> get("/reset/invalid-token")
    assert AuthReturnSession.destination(get_session(conn)) == "/discover?q=Elixir%2FPhoenix"
    assert conn.resp_body =~ "return_to=%2Fdiscover%3Fq%3DElixir%252FPhoenix"
  end

  test "successful authentication consumes the pending destination, while a failure preserves it",
       %{conn: conn} do
    member = generate(user())
    {:ok, token, _} = AshAuthentication.Jwt.token_for_user(member, %{}, domain: Huddlz.Accounts)
    member = Ash.Resource.put_metadata(member, :token, token)
    pending = %{"path" => "/help/agents", "at" => System.system_time(:second)}

    conn =
      conn |> init_test_session(%{"return_to" => pending}) |> Phoenix.Controller.fetch_flash([])

    conn = %{conn | params: %{}}
    failure = HuddlzWeb.AuthController.failure(conn, {:password, :sign_in}, :invalid)
    assert redirected_to(failure) == "/sign-in?return_to=%2Fhelp%2Fagents"
    assert get_session(failure, :return_to) == pending
    success = HuddlzWeb.AuthController.success(conn, {:password, :sign_in}, member, token)
    assert redirected_to(success) == "/help/agents"
    assert get_session(success, :return_to) == nil
  end

  test "new bare or unsafe authentication journeys clear an old destination", %{conn: conn} do
    for path <- ["/sign-in", "/register", "/reset", "/sign-in?return_to=%2F%2Fevil.example"] do
      conn =
        conn
        |> init_test_session(%{
          "return_to" => %{"path" => "/help", "at" => System.system_time(:second)}
        })
        |> get(path)

      assert get_session(conn, :return_to) == nil
    end
  end

  test "an already authenticated visit cannot leave a pending destination", %{conn: conn} do
    conn = conn |> login(generate(user())) |> get("/sign-in?return_to=%2Fhelp")
    assert get_session(conn, :return_to) == nil
  end

  test "expired, future, malformed and unsafe pending destinations fail closed" do
    now = 10_000

    for pending <- [
          %{"path" => "/help", "at" => now - 1801},
          %{"path" => "/help", "at" => now + 1},
          %{"path" => "//evil.example", "at" => now},
          %{"path" => "/help", "at" => "bad"},
          "/help",
          nil
        ] do
      assert AuthReturnSession.destination(%{"return_to" => pending}, now) == nil
    end

    assert AuthReturnSession.destination(
             %{"return_to" => %{"path" => "/help", "at" => now - 1800}},
             now
           ) == "/help"
  end
end

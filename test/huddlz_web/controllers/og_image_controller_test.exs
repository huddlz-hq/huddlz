defmodule HuddlzWeb.OgImageControllerTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator

  setup do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    huddl =
      generate(huddl(group_id: group.id, creator_id: owner.id, is_private: false, actor: owner))

    %{huddl: huddl}
  end

  test "serves the card with a strong ETag and honours If-None-Match", %{conn: conn, huddl: huddl} do
    first = get(conn, ~p"/og/huddlz/#{huddl.id}/card.png")

    assert first.status == 200
    assert [etag] = get_resp_header(first, "etag")
    assert ["public, max-age=3600"] = get_resp_header(first, "cache-control")

    cached =
      conn
      |> put_req_header("if-none-match", etag)
      |> get(~p"/og/huddlz/#{huddl.id}/card.png")

    assert cached.status == 304
    assert cached.resp_body == ""
  end

  test "an unknown huddl is not found", %{conn: conn} do
    assert conn |> get(~p"/og/huddlz/#{Ecto.UUID.generate()}/card.png") |> response(404)
  end
end

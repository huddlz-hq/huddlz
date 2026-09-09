defmodule HuddlzWeb.Api.Graphql.ViewerTest do
  use HuddlzWeb.ApiCase, async: true

  test "the schema exposes viewer queries without the retired personal names", %{conn: conn} do
    response =
      conn
      |> gql_post("{ __schema { queryType { fields { name } } } }")
      |> json_response(200)

    names = Enum.map(response["data"]["__schema"]["queryType"]["fields"], & &1["name"])

    assert "viewerGroups" in names
    assert "viewerMemberships" in names
    assert "viewerRsvps" in names
    refute "myGroups" in names
    refute "myMemberships" in names
    refute "myRsvps" in names
  end

  test "viewerRsvps returns only the authenticated user's RSVPs", %{conn: conn} do
    owner = generate(user())
    viewer = generate(user())
    group = generate(group(actor: owner, is_public: true))
    huddl = generate(huddl(group_id: group.id, actor: owner, is_private: false))
    Huddlz.Communities.rsvp_huddl!(huddl, actor: owner)
    Huddlz.Communities.rsvp_huddl!(huddl, actor: viewer)
    [rsvp] = Huddlz.Communities.check_user_rsvp!(huddl.id, actor: viewer)

    response =
      conn
      |> authenticated_conn(viewer)
      |> gql_post("{ viewerRsvps { id } }")
      |> json_response(200)

    assert response == %{
             "data" => %{
               "viewerRsvps" => [%{"id" => rsvp.id}]
             }
           }
  end

  test "viewerMemberships returns only the authenticated user's memberships", %{conn: conn} do
    owner = generate(user())
    viewer = generate(user())
    group = generate(group(actor: owner, is_public: true))
    membership = generate(group_member(group_id: group.id, user_id: viewer.id, actor: owner))

    response =
      conn
      |> authenticated_conn(viewer)
      |> gql_post("{ viewerMemberships { id } }")
      |> json_response(200)

    assert response == %{"data" => %{"viewerMemberships" => [%{"id" => membership.id}]}}
  end
end

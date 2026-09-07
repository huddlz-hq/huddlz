defmodule ApiArtworkSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator

  step "public upcoming huddlz with their own artwork, group artwork, and no artwork", context do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    empty_group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    direct = generate(huddl(group_id: group.id, actor: owner, thumbnail_url: nil))
    fallback = generate(huddl(group_id: group.id, actor: owner, thumbnail_url: nil))
    empty = generate(huddl(group_id: empty_group.id, actor: owner, thumbnail_url: nil))

    group_image = upload(Huddlz.Communities.GroupImage, :group_id, group.id, owner)
    huddl_image = upload(Huddlz.Communities.HuddlCoverImage, :huddl_id, direct.id, owner)

    Map.put(context, :artwork, %{
      direct.id => HuddlzWeb.Endpoint.url() <> huddl_image.thumbnail_path,
      fallback.id => HuddlzWeb.Endpoint.url() <> group_image.thumbnail_path,
      empty.id => nil
    })
  end

  step "I discover those huddlz and open their details through the API without signing in",
       context do
    discovery = get(context.conn, "/api/json/huddlz?date_filter=upcoming")
    details = for id <- Map.keys(context.artwork), do: get(context.conn, "/api/json/huddlz/#{id}")
    Map.merge(context, %{artwork_discovery: discovery, artwork_details: details})
  end

  step "both API responses provide the available artwork or no artwork", context do
    discovery = Phoenix.ConnTest.json_response(context.artwork_discovery, 200)["data"]

    details =
      Enum.map(context.artwork_details, &Phoenix.ConnTest.json_response(&1, 200)["data"])

    for records <- [discovery, details] do
      actual = Map.new(records, &{&1["id"], Map.fetch!(&1["attributes"], "image_url")})
      assert actual == context.artwork
    end

    context
  end

  step "the available artwork can be downloaded", context do
    for url <- Map.values(context.artwork), url do
      conn = get(context.conn, URI.parse(url).path)
      assert byte_size(Phoenix.ConnTest.response(conn, 200)) > 0
      assert Plug.Conn.get_resp_header(conn, "content-type") == ["image/jpeg"]
    end

    context
  end

  defp get(conn, path) do
    Phoenix.ConnTest.dispatch(conn, HuddlzWeb.Endpoint, :get, path, nil)
  end

  defp upload(resource, parent_key, parent_id, owner) do
    file = %Plug.Upload{
      path: "test/fixtures/test_image.jpg",
      filename: "cover.jpg",
      content_type: "image/jpeg"
    }

    image =
      resource
      |> Ash.Changeset.for_create(:upload, %{parent_key => parent_id, :file => file},
        actor: owner
      )
      |> Ash.create!()

    ExUnit.Callbacks.on_exit(fn ->
      for path <- [image.storage_path, image.thumbnail_path], do: Huddlz.Storage.delete(path)
    end)

    image
  end
end

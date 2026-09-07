defmodule PhotoCompatibilitySteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest

  step "a host with a huddl needing a cover", context do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, actor: owner))
    huddl = generate(huddl(group_id: group.id, actor: owner))

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/huddl_cover_images/#{huddl.id}")
    end)

    Map.merge(context, %{owner: owner, huddl: huddl})
  end

  step "the host uploads a cover using the established API", context do
    conn =
      context.conn
      |> authenticated_conn(context.owner)
      |> multipart_post(
        "/api/json/huddl_images/upload",
        %{"huddl_id" => context.huddl.id, "file" => "photo"},
        type: "huddl_image",
        file: %{
          part_name: "photo",
          path: "test/fixtures/test_image.jpg",
          filename: "cover.jpg",
          content_type: "image/jpeg"
        }
      )

    Map.put(context, :response, conn)
  end

  step "the cover is available and the established GraphQL upload remains available", context do
    assert %{"data" => %{"type" => "huddl_image", "attributes" => %{"thumbnail_path" => path}}} =
             json_response(context.response, 201)

    response = Phoenix.ConnTest.dispatch(build_conn(), HuddlzWeb.Endpoint, :get, path, nil)
    assert byte_size(response(response, 200)) > 0
    response = gql_post(build_conn(), "{ __schema { mutationType { fields { name } } } }")
    fields = json_response(response, 200)["data"]["__schema"]["mutationType"]["fields"]
    assert Enum.any?(fields, &(&1["name"] == "uploadHuddlImage"))
    context
  end
end

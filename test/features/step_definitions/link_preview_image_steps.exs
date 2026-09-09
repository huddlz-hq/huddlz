defmodule LinkPreviewImageSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Phoenix.ConnTest

  @endpoint HuddlzWeb.Endpoint

  step "a public group {string} hosting an upcoming huddl {string} with no cover picture",
       %{args: [group_name, title]} = context do
    owner = generate(user(role: :user))
    group = generate(group(name: group_name, is_public: true, owner_id: owner.id, actor: owner))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: owner.id,
          is_private: false,
          title: title,
          actor: owner
        )
      )

    Map.merge(context, %{group: group, huddl: huddl})
  end

  step "a private huddl {string} with no cover picture", %{args: [title]} = context do
    owner = generate(user(role: :user))
    group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: owner.id,
          is_private: true,
          title: title,
          actor: owner
        )
      )

    Map.merge(context, %{group: group, huddl: huddl})
  end

  step "a link preview fetches the huddl page", context do
    html =
      context.conn
      |> get("/groups/#{context.group.slug}/huddlz/#{context.huddl.id}")
      |> html_response(200)

    Map.put(context, :page_html, html)
  end

  step "the page advertises a generated preview picture", context do
    [image_url] =
      context.page_html
      |> Floki.parse_document!()
      |> Floki.attribute(~s(meta[property="og:image"]), "content")

    assert image_url == HuddlzWeb.Endpoint.url() <> "/og/huddlz/#{context.huddl.id}/card.png"

    Map.put(context, :image_url, image_url)
  end

  step "that picture is a 1200 by 630 PNG", context do
    path = URI.parse(context.image_url).path
    response = get(build_conn(), path)

    assert response.status == 200
    assert response_content_type(response, :png) =~ "image/png"

    {:ok, image} = Image.from_binary(response.resp_body)
    assert {Image.width(image), Image.height(image)} == {1200, 630}

    context
  end

  step "a link preview fetches that huddl's preview picture", context do
    Map.put(context, :response, get(build_conn(), "/og/huddlz/#{context.huddl.id}/card.png"))
  end

  step "there is nothing to fetch", context do
    assert context.response.status == 404
    context
  end
end

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

  step "a public group {string} with a cover picture", %{args: [group_name]} = context do
    owner = generate(user(role: :user))
    group = generate(group(name: group_name, is_public: true, owner_id: owner.id, actor: owner))
    thumbnail_path = "/uploads/group_images/#{group.id}/cover_thumb.jpg"

    Huddlz.Communities.create_group_image!(
      %{
        filename: "cover.jpg",
        content_type: "image/jpeg",
        size_bytes: 1234,
        storage_path: "/uploads/group_images/#{group.id}/cover.jpg",
        thumbnail_path: thumbnail_path,
        group_id: group.id
      },
      actor: owner
    )

    Map.merge(context, %{group: group, owner: owner, group_cover_path: thumbnail_path})
  end

  step "an upcoming huddl {string} in that group with no cover of its own",
       %{args: [title]} = context do
    huddl =
      generate(
        huddl(
          group_id: context.group.id,
          creator_id: context.owner.id,
          is_private: false,
          title: title,
          actor: context.owner
        )
      )

    Map.put(context, :huddl, huddl)
  end

  step "the page advertises the group's cover picture", context do
    [image_url] =
      context.page_html
      |> Floki.parse_document!()
      |> Floki.attribute(~s(meta[property="og:image"]), "content")

    assert image_url == HuddlzWeb.Endpoint.url() <> context.group_cover_path
    refute image_url =~ "/og/huddlz/"

    context
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

  step "a public group {string} with no cover picture", %{args: [group_name]} = context do
    owner = generate(user(role: :user))

    group =
      generate(
        group(
          name: group_name,
          is_public: true,
          location: "Saint Augustine, FL",
          owner_id: owner.id,
          actor: owner
        )
      )

    Map.put(context, :group, group)
  end

  step "a private group {string}", %{args: [group_name]} = context do
    owner = generate(user(role: :user))
    group = generate(group(name: group_name, is_public: false, owner_id: owner.id, actor: owner))
    Map.put(context, :group, group)
  end

  step "a link preview fetches the home page", context do
    Map.put(context, :page_html, context.conn |> get("/") |> html_response(200))
  end

  step "a link preview fetches the discover page", context do
    Map.put(context, :page_html, context.conn |> get("/discover") |> html_response(200))
  end

  step "the page advertises the huddlz site card as its preview picture", context do
    [image_url] = preview_images(context.page_html)
    assert image_url == HuddlzWeb.Endpoint.url() <> "/og/card.png"
    Map.put(context, :image_url, image_url)
  end

  step "the page does not advertise the site card", context do
    refute (HuddlzWeb.Endpoint.url() <> "/og/card.png") in preview_images(context.page_html)
    context
  end

  step "a link preview fetches the group page", context do
    html =
      context.conn
      |> get("/groups/#{context.group.slug}")
      |> html_response(200)

    Map.put(context, :page_html, html)
  end

  step "the page advertises a generated group preview picture", context do
    [image_url] =
      context.page_html
      |> Floki.parse_document!()
      |> Floki.attribute(~s(meta[property="og:image"]), "content")

    assert image_url == HuddlzWeb.Endpoint.url() <> "/og/groups/#{context.group.slug}/card.png"

    Map.put(context, :image_url, image_url)
  end

  step "a link preview fetches that group's preview picture", context do
    Map.put(context, :response, get(build_conn(), "/og/groups/#{context.group.slug}/card.png"))
  end

  defp preview_images(html) do
    html |> Floki.parse_document!() |> Floki.attribute(~s(meta[property="og:image"]), "content")
  end
end

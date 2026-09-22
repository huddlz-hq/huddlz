defmodule ShareLinksSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication, only: [login: 2]
  import PhoenixTest

  step "a public huddl {string}", %{args: [title]} = context do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

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

  step "a public group {string}", %{args: [name]} = context do
    owner = generate(user(role: :user))
    group = generate(group(name: name, is_public: true, owner_id: owner.id, actor: owner))
    Map.put(context, :group, group)
  end

  step "I am a member of a private group with a huddl {string}", %{args: [title]} = context do
    owner = generate(user(role: :user))
    member = generate(user(role: :user))
    group = generate(group(is_public: false, owner_id: owner.id, actor: owner))
    generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

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

    session = Phoenix.ConnTest.build_conn() |> login(member) |> visit("/")

    Map.merge(context, %{group: group, huddl: huddl, session: session, conn: session})
  end

  step "I am signed out", context do
    Map.merge(context, %{session: nil, conn: nil})
  end

  step "I open the group page", context do
    session = context[:session] || context[:conn] || Phoenix.ConnTest.build_conn()
    session = visit(session, "/groups/#{context.group.slug}")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I open the huddl page", context do
    session = context[:session] || context[:conn] || Phoenix.ConnTest.build_conn()
    session = visit(session, "/groups/#{context.group.slug}/huddlz/#{context.huddl.id}")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I can copy the huddl's link from the Share section", context do
    assert_copies(context.session, huddl_url(context.group, context.huddl))
    context
  end

  step "I choose to share it on {string}", %{args: [platform]} = context do
    [href] =
      context.session
      |> html()
      |> Floki.find("#share-actions a")
      |> Enum.filter(&(Floki.text(&1) |> String.trim() == platform))
      |> Floki.attribute("href")

    Map.merge(context, %{share_platform: platform, share_href: href})
  end

  step "the compose screen opens with {string} and the huddl's link", %{args: [text]} = context do
    assert_compose(context, text, huddl_url(context.group, context.huddl))
    context
  end

  step "the compose screen opens with {string} and the group's link", %{args: [text]} = context do
    assert_compose(context, text, group_url(context.group))
    context
  end

  step "I can copy the group's link from the Share section", context do
    assert_copies(context.session, group_url(context.group))
    context
  end

  step "the Share section offers X, Bluesky, Threads, Facebook, LinkedIn and WhatsApp", context do
    for name <- ~w(X Bluesky Threads Facebook LinkedIn WhatsApp) do
      assert_has(context.session, "#share-actions a[target='_blank']", text: name, exact: true)
    end

    context
  end

  step "the Share section offers no platform links", context do
    refute_has(context.session, "#share-actions a[target='_blank']")
    context
  end

  step "it explains that Instagram and Mastodon take a copied link", context do
    assert_has(context.session, "#share-actions", text: "Instagram")
    assert_has(context.session, "#share-actions", text: "Mastodon")
    context
  end

  defp assert_compose(%{share_platform: platform, share_href: href}, text, url) do
    uri = URI.parse(href)
    query = URI.decode_query(uri.query || "")
    filled = query |> Map.values() |> Enum.join(" ")

    assert compose_host(platform) == uri.host,
           "expected the #{platform} link to open #{compose_host(platform)}, got #{href}"

    assert filled =~ text, "expected the #{platform} compose screen to carry #{inspect(text)}"
    assert filled =~ url, "expected the #{platform} compose screen to carry the link"
  end

  defp compose_host("Bluesky"), do: "bsky.app"
  defp compose_host("X"), do: "x.com"
  defp compose_host("Threads"), do: "www.threads.net"
  defp compose_host("Facebook"), do: "www.facebook.com"
  defp compose_host("LinkedIn"), do: "www.linkedin.com"
  defp compose_host("WhatsApp"), do: "wa.me"

  defp html(%{view: view}), do: view |> Phoenix.LiveViewTest.render() |> Floki.parse_fragment!()

  defp html(%{conn: conn}),
    do: conn |> Phoenix.ConnTest.html_response(200) |> Floki.parse_document!()

  defp assert_copies(session, url) do
    assert_has(session, "#share-actions button[data-value='#{url}']", text: "Copy link")
  end

  defp huddl_url(group, huddl), do: group_url(group) <> "/huddlz/#{huddl.id}"
  defp group_url(group), do: HuddlzWeb.Endpoint.url() <> "/groups/#{group.slug}"
end

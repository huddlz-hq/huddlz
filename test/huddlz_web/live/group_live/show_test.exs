defmodule HuddlzWeb.GroupLive.ShowTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Test.Helpers.Authentication

  alias Huddlz.Communities

  describe "responsive group cover" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      %{owner: owner, group: group}
    end

    test "renders a branded fallback when no cover is available", %{conn: conn, group: group} do
      conn
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("#group-detail-hero.group-hero")
      |> assert_has("#group-detail-cover-#{group.id} [aria-hidden='true']")
      |> assert_has("#group-detail-cover-#{group.id} .group-cover-signal")
      |> refute_has("#group-detail-cover-#{group.id} .cover-image")
    end

    test "renders a decorative cover with a fallback", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      {:ok, _image} =
        Communities.create_group_image(
          %{
            filename: "cover.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/group_images/#{group.id}/cover.jpg",
            thumbnail_path: "/uploads/group_images/#{group.id}/cover_thumb.jpg",
            group_id: group.id
          },
          actor: owner
        )

      conn
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("#group-detail-cover-#{group.id}-image[aria-hidden='true'][style]")
      |> assert_has("#group-detail-cover-#{group.id} .group-cover-fallback")
    end
  end

  describe "page layout" do
    setup do
      owner = generate(user(role: :user))

      group =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            name: "Phoenix Elixir",
            location: "Phoenix, AZ",
            actor: owner
          )
        )

      %{owner: owner, group: group}
    end

    test "stacks the cover above the title with a visibility pill and meta", %{
      conn: conn,
      group: group
    } do
      conn
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("header#group-detail-hero.group-hero .hero-media .group-cover--hero")
      |> assert_has("header#group-detail-hero .hero-content .pill.cyan", text: "Public group")
      |> assert_has("header#group-detail-hero .hero-content h1", text: "Phoenix Elixir")
      |> assert_has(".group-hero-meta .group-hero-location", text: "Phoenix, AZ")
      |> assert_has(".group-hero-meta .meta-item", text: "1 member")
      |> refute_has(".huddl-side h3", text: "This group")
    end

    test "groups the owner's actions in the side panel", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has(".side-actions .role-pill .pill", text: "Owner")
      |> assert_has(
        ".side-actions a.side-actions-primary[href='/groups/#{group.slug}/huddlz/new']",
        text: "Create Huddl"
      )
      |> assert_has(".side-actions-row a[href='/groups/#{group.slug}/edit']", text: "Edit Group")
      |> assert_has(".side-actions-row a[href='/groups/#{group.slug}/locations']",
        text: "Locations"
      )
    end

    test "shows an empty state until the group has an upcoming huddl", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      conn
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("#group-huddl-grid-empty.empty-state h3", text: "Nothing scheduled")
      |> assert_has("#group-huddl-grid-empty p", text: "No upcoming huddlz scheduled.")
      |> assert_has(".group-huddlz .list-head h2", text: "Huddlz")
      |> assert_has(".group-huddlz .list-head .filters .chip.is-active", text: "Upcoming")

      generate(huddl(group_id: group.id, creator_id: owner.id, is_private: false, actor: owner))

      conn
      |> visit(~p"/groups/#{group.slug}")
      |> refute_has("#group-huddl-grid-empty")
      |> assert_has("#group-huddl-grid .card", count: 1)
    end

    test "huddl cards fall back to the group's initials without a cover", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      bare =
        generate(huddl(group_id: group.id, creator_id: owner.id, is_private: false, actor: owner))

      pictured =
        generate(huddl(group_id: group.id, creator_id: owner.id, is_private: false, actor: owner))

      Huddlz.Communities.HuddlCoverImage
      |> Ash.Changeset.for_create(:create, %{
        filename: "cover.jpg",
        content_type: "image/jpeg",
        size_bytes: 123,
        storage_path: "/uploads/huddl_cover_images/#{pictured.id}/cover.jpg",
        thumbnail_path: "/uploads/huddl_cover_images/#{pictured.id}/cover_thumb.jpg",
        huddl_id: pictured.id
      })
      |> Ash.create!(authorize?: false)

      bare_card = ~s(#group-huddl-grid .card[href="/groups/#{group.slug}/huddlz/#{bare.id}"])

      pictured_card =
        ~s(#group-huddl-grid .card[href="/groups/#{group.slug}/huddlz/#{pictured.id}"])

      conn
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("#{bare_card} .card-cover-fallback", text: "PE", exact: true)
      |> refute_has("#{bare_card} .cover-image")
      |> assert_has("#{pictured_card} #group-huddl-card-cover-#{pictured.id}.cover-image")
      |> refute_has("#{pictured_card} .card-cover-fallback")
    end
  end

  describe "membership action buttons" do
    setup do
      owner = generate(user(role: :user))

      group =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            name: "Membership Test Group",
            actor: owner
          )
        )

      %{owner: owner, group: group}
    end

    test "join button shows a pending state while submitting", %{conn: conn, group: group} do
      visitor = generate(user(role: :user))

      conn
      |> login(visitor)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("button[phx-disable-with='Joining...']", text: "Join Group")
    end

    test "leave button opens an in-app confirmation without changing membership", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      member = generate(user(role: :user))

      generate(
        group_member(
          group_id: group.id,
          user_id: member.id,
          role: :member,
          actor: owner
        )
      )

      session =
        conn
        |> login(member)
        |> visit(~p"/groups/#{group.slug}")
        |> refute_has("button[data-confirm]", text: "Leave Group")
        |> click_button("Leave Group")
        |> assert_has("#leave-group-dialog [role='dialog']")
        |> assert_has("#leave-group-dialog-title", text: "Leave Membership Test Group?")
        |> assert_has("#leave-group-dialog", text: "member roster")
        |> assert_has("#leave-group-dialog", text: "My groups")
        |> assert_has("#leave-group-dialog", text: "notifications")
        |> assert_has(
          "#leave-group-dialog-container[phx-key='escape'][phx-window-keydown][phx-click-away]"
        )
        |> assert_has("#leave-group-dialog-cancel", text: "Cancel")

      session
      |> within("#leave-group-dialog", fn session ->
        click_button(session, "Cancel")
      end)
      |> refute_has("#leave-group-dialog")
      |> assert_has("button", text: "Leave Group")
    end

    test "confirming leave updates the group page and My groups", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      member = generate(user(role: :user))

      generate(
        group_member(
          group_id: group.id,
          user_id: member.id,
          role: :member,
          actor: owner
        )
      )

      conn
      |> login(member)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has(".facts li", text: "Members 2")
      |> click_button("Leave Group")
      |> within("#leave-group-dialog", fn session ->
        click_button(session, "Yes, leave group")
      end)
      |> assert_has("*", text: "Successfully left the group")
      |> assert_has(".facts li", text: "Members 1")
      |> refute_has("button", text: "Leave Group")
      |> assert_has("button", text: "Join Group")
      |> visit(~p"/my-groups")
      |> refute_has("*", text: "Membership Test Group")
    end

    test "joining updates the member count without a refresh", %{
      conn: conn,
      group: group
    } do
      visitor = generate(user(role: :user))

      conn
      |> login(visitor)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has(".facts li", text: "Members 1")
      |> click_button("Join Group")
      |> assert_has("*", text: "Successfully joined the group!")
      |> assert_has(".facts li", text: "Members 2")
    end

    test "owner cannot open the leave dialog", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> refute_has("button", text: "Leave Group")
      |> refute_has("#leave-group-dialog")
    end
  end

  describe "share links" do
    test "sidebar share section offers a mailto email link and a QR code modal", %{
      conn: conn
    } do
      owner = generate(user(role: :user))

      group =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            name: "Share Test Group",
            actor: owner
          )
        )

      group_url = HuddlzWeb.Endpoint.url() <> ~p"/groups/#{group.slug}"

      conn
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("aside.huddl-side h3", text: "Share")
      |> assert_has("#share-group-modal-email[href^='mailto:?subject=Share%20Test%20Group']")
      |> assert_has("#share-group-modal-open[phx-click*='share-group-modal']")
      |> assert_has("#share-group-modal-url[value='#{group_url}']")
      |> assert_has(
        "#share-group-modal-copy[data-copy-target='#share-group-modal-url'] #share-group-modal-copy-label[phx-hook='ClipboardCopy'][phx-update='ignore']"
      )
      |> assert_has("#share-group-modal .qr-frame svg")
    end
  end
end

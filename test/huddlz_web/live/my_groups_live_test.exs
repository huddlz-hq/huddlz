defmodule HuddlzWeb.MyGroupsLiveTest do
  use HuddlzWeb.ConnCase, async: true

  setup do
    member = generate(user(role: :user))
    other = generate(user(role: :user))
    %{member: member, other: other}
  end

  describe "anonymous access" do
    test "redirects to sign-in", %{conn: conn} do
      conn
      |> visit("/my-groups")
      |> assert_path("/sign-in")
    end
  end

  describe "page chrome" do
    test "renders v3 sidebar with My groups active", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups")
      |> assert_has("h1", text: "My groups")
      |> assert_has("aside.sidebar")
      |> assert_has(".sb-item.active", text: "My groups")
    end

    test "shows three filter chips with counts", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups")
      |> assert_has(".filters .chip", text: "All")
      |> assert_has(".filters .chip", text: "Hosting")
      |> assert_has(".filters .chip", text: "Joined")
    end

    test "All chip is active by default", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups")
      |> assert_has(".filters .chip.is-active", text: "All")
    end

    test "Start a group CTA links to /groups/new", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups")
      |> assert_has(".page-head a[href='/groups/new']", text: "Start a group")
    end
  end

  describe "All filter (default)" do
    test "merges hosting and joined groups", %{conn: conn, member: member, other: other} do
      _hosted =
        generate(group(name: "Hosted Crew", is_public: true, owner_id: member.id, actor: member))

      joined_group =
        generate(group(name: "Joined Crew", is_public: true, owner_id: other.id, actor: other))

      generate(group_member(group_id: joined_group.id, user_id: member.id, actor: other))

      conn
      |> login(member)
      |> visit("/my-groups")
      |> assert_has(".grid .card .card-title", text: "Hosted Crew")
      |> assert_has(".grid .card .card-title", text: "Joined Crew")
      |> assert_has(".filters .chip", text: "All · 2")
      |> assert_has(".filters .chip", text: "Hosting · 1")
      |> assert_has(".filters .chip", text: "Joined · 1")
    end

    test "empty state copy", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups")
      |> assert_has("p",
        text: "You haven't organized or joined any groups yet. Start one or browse Discover."
      )
    end
  end

  describe "Hosting filter" do
    test "shows only owned groups with Hosting tag", %{
      conn: conn,
      member: member,
      other: other
    } do
      generate(group(name: "Owned One", is_public: true, owner_id: member.id, actor: member))

      joined_group =
        generate(group(name: "Joined One", is_public: true, owner_id: other.id, actor: other))

      generate(group_member(group_id: joined_group.id, user_id: member.id, actor: other))

      conn
      |> login(member)
      |> visit("/my-groups?filter=hosting")
      |> assert_has(".filters .chip.is-active", text: "Hosting")
      |> assert_has(".grid .card .card-title", text: "Owned One")
      |> refute_has(".grid .card .card-title", text: "Joined One")
      |> assert_has(".grid .card .card-tag", text: "Hosting")
    end

    test "empty state copy", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups?filter=hosting")
      |> assert_has("p", text: "You haven't created a group yet.")
    end
  end

  describe "Joined filter" do
    test "shows only joined groups with Joined tag", %{
      conn: conn,
      member: member,
      other: other
    } do
      _hosted =
        generate(group(name: "Owned One", is_public: true, owner_id: member.id, actor: member))

      joined_group =
        generate(group(name: "Joined One", is_public: true, owner_id: other.id, actor: other))

      generate(group_member(group_id: joined_group.id, user_id: member.id, actor: other))

      conn
      |> login(member)
      |> visit("/my-groups?filter=joined")
      |> assert_has(".filters .chip.is-active", text: "Joined")
      |> assert_has(".grid .card .card-title", text: "Joined One")
      |> refute_has(".grid .card .card-title", text: "Owned One")
      |> assert_has(".grid .card .card-tag", text: "Joined")
    end

    test "empty state copy", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups?filter=joined")
      |> assert_has("p", text: "You haven't joined any groups yet.")
    end
  end

  describe "URL filtering" do
    test "unknown filter falls back to All", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups?filter=garbage")
      |> assert_has(".filters .chip.is-active", text: "All")
    end
  end

  describe "scoping" do
    test "does not leak groups the user has no relationship with", %{
      conn: conn,
      member: member,
      other: other
    } do
      _stranger_group =
        generate(group(name: "Strangers Only", is_public: true, owner_id: other.id, actor: other))

      conn
      |> login(member)
      |> visit("/my-groups")
      |> refute_has(".grid .card .card-title", text: "Strangers Only")
      |> assert_has(".filters .chip", text: "All · 0")
    end
  end

  describe "card destinations" do
    test "card links to /groups/:slug", %{conn: conn, member: member} do
      group =
        generate(group(name: "Linked Group", is_public: true, owner_id: member.id, actor: member))

      conn
      |> login(member)
      |> visit("/my-groups")
      |> assert_has(~s(.grid .card[href="/groups/#{group.slug}"]))
    end
  end

  describe "card content" do
    test "renders member count", %{conn: conn, member: member} do
      _g =
        generate(group(name: "Crowded Crew", is_public: true, owner_id: member.id, actor: member))

      conn
      |> login(member)
      |> visit("/my-groups")
      |> assert_has(".grid .card .card-meta", text: "1 member")
    end
  end

  describe "alphabetical sort" do
    test "groups appear in case-insensitive alphabetical order", %{
      conn: conn,
      member: member
    } do
      generate(group(name: "zebra", is_public: true, owner_id: member.id, actor: member))
      generate(group(name: "Alpha", is_public: true, owner_id: member.id, actor: member))
      generate(group(name: "mango", is_public: true, owner_id: member.id, actor: member))

      session =
        conn
        |> login(member)
        |> visit("/my-groups")

      html = Phoenix.LiveViewTest.render(session.view)

      alpha_idx = :binary.match(html, "Alpha") |> elem(0)
      mango_idx = :binary.match(html, "mango") |> elem(0)
      zebra_idx = :binary.match(html, "zebra") |> elem(0)

      assert alpha_idx < mango_idx
      assert mango_idx < zebra_idx
    end
  end

  describe "pagination" do
    setup %{member: member} do
      # 22 owned groups → 2 pages of 20
      for i <- 1..22 do
        slug = String.pad_leading(Integer.to_string(i), 3, "0")

        generate(
          group(
            name: "Group #{slug}",
            is_public: true,
            owner_id: member.id,
            actor: member
          )
        )
      end

      :ok
    end

    test "shows pagination when more than 20 groups", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups")
      |> assert_has(".grid .card .card-title", text: "Group 001")
      |> assert_has(".grid .card .card-title", text: "Group 020")
      |> refute_has(".grid .card .card-title", text: "Group 021")
      |> assert_has(".pagination .page-num", text: "2")
    end

    test "page=2 shows the next 20", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups?page=2")
      |> assert_has(".grid .card .card-title", text: "Group 021")
      |> assert_has(".grid .card .card-title", text: "Group 022")
      |> refute_has(".grid .card .card-title", text: "Group 001")
    end

    test "out-of-range ?page= clamps to last valid page", %{conn: conn, member: member} do
      conn
      |> login(member)
      |> visit("/my-groups?page=999")
      |> assert_path("/my-groups", query_params: %{"page" => "2"})
    end
  end
end

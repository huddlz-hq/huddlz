defmodule HuddlzWeb.MyHuddlzLiveTest do
  use HuddlzWeb.ConnCase, async: true

  setup do
    host = generate(user(role: :user))
    attendee = generate(user(role: :user))
    public_group = generate(group(is_public: true, owner_id: host.id, actor: host))

    %{host: host, attendee: attendee, public_group: public_group}
  end

  defp rsvp!(huddl, user, action) do
    huddl
    |> Ash.Changeset.for_update(action, %{}, actor: user)
    |> Ash.update!()
  end

  defp create_huddl(host, group, opts) do
    generate(
      huddl(
        Keyword.merge(
          [
            group_id: group.id,
            creator_id: host.id,
            is_private: false,
            actor: host
          ],
          opts
        )
      )
    )
  end

  defp create_past_huddl(host, group, opts) do
    generate(
      past_huddl(
        Keyword.merge(
          [
            group_id: group.id,
            creator_id: host.id,
            is_private: false,
            actor: host
          ],
          opts
        )
      )
    )
  end

  describe "anonymous access" do
    test "redirects to sign-in", %{conn: conn} do
      conn
      |> visit("/my-huddlz")
      |> assert_path("/sign-in")
    end
  end

  describe "page chrome" do
    test "renders v3 sidebar with My huddlz active", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz")
      |> assert_has("h1", text: "My huddlz")
      |> assert_has("aside.sidebar")
      |> assert_has(".sb-item.active", text: "My huddlz")
    end

    test "shows three filter chips with counts", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz")
      |> assert_has(".filters .chip", text: "Upcoming")
      |> assert_has(".filters .chip", text: "Waitlisted")
      |> assert_has(".filters .chip", text: "Past")
    end

    test "Upcoming chip is active by default", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz")
      |> assert_has(".filters .chip.is-active", text: "Upcoming")
    end
  end

  describe "Upcoming filter (default)" do
    test "shows attending huddlz", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      huddl_attended = create_huddl(host, public_group, title: "Going Show")
      _other_huddl = create_huddl(host, public_group, title: "Skipped Show")

      rsvp!(huddl_attended, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/my-huddlz")
      |> assert_has("h3.card-title", text: "Going Show")
      |> refute_has("h3.card-title", text: "Skipped Show")
      |> assert_has(".pill", text: "Going")
    end

    test "empty state shows helpful copy", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz")
      |> assert_has("p", text: "No upcoming RSVPs yet. Find one to attend.")
    end

    test "Upcoming count reflects attended huddlz", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Counted")
      rsvp!(huddl, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/my-huddlz")
      |> assert_has(".filters .chip", text: "Upcoming · 1")
    end
  end

  describe "Waitlisted filter" do
    setup ctx do
      huddl =
        create_huddl(ctx.host, ctx.public_group,
          title: "Sold Out Show",
          max_attendees: 1
        )

      # First attendee fills the seat
      filler = generate(user(role: :user))
      rsvp!(huddl, filler, :rsvp)

      # Reload the huddl with current count
      huddl = Ash.reload!(huddl)

      Map.put(ctx, :huddl, huddl)
    end

    test "shows waitlisted huddlz with Waitlist pill", %{
      conn: conn,
      attendee: attendee,
      huddl: huddl
    } do
      rsvp!(huddl, attendee, :join_waitlist)

      conn
      |> login(attendee)
      |> visit("/my-huddlz?filter=waitlisted")
      |> assert_has(".filters .chip.is-active", text: "Waitlisted")
      |> assert_has("h3.card-title", text: "Sold Out Show")
      |> assert_has(".pill", text: "Waitlist")
    end

    test "empty state copy", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz?filter=waitlisted")
      |> assert_has("p", text: "You're not on a waitlist right now.")
    end
  end

  describe "Past filter" do
    test "shows attended past huddlz with Attended pill", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      past = create_past_huddl(host, public_group, title: "Old Workshop")
      rsvp!(past, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/my-huddlz?filter=past")
      |> assert_has(".filters .chip.is-active", text: "Past")
      |> assert_has("h3.card-title", text: "Old Workshop")
      |> assert_has(".pill", text: "Attended")
    end

    test "empty state copy", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz?filter=past")
      |> assert_has("p", text: "No past attendance yet.")
    end
  end

  describe "legacy /me redirects" do
    test "bare /me redirects to /my-huddlz", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/me")
      |> assert_path("/my-huddlz")
    end

    test "/me?tab=huddlz redirects to /my-huddlz", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/me?tab=huddlz")
      |> assert_path("/my-huddlz")
    end

    test "/me?tab=garbage falls back to /my-huddlz", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/me?tab=garbage")
      |> assert_path("/my-huddlz")
    end

    test "anonymous visit to /me lands at /sign-in", %{conn: conn} do
      conn
      |> visit("/me")
      |> assert_path("/sign-in")
    end
  end

  describe "URL filtering" do
    test "unknown filter falls back to Upcoming", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz?filter=garbage")
      |> assert_has(".filters .chip.is-active", text: "Upcoming")
    end
  end

  describe "scoping" do
    test "does not leak other users' RSVPs into Upcoming", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      mine = create_huddl(host, public_group, title: "I Am Going")
      theirs = create_huddl(host, public_group, title: "They Are Going")

      rsvp!(mine, attendee, :rsvp)

      stranger = generate(user(role: :user))
      rsvp!(theirs, stranger, :rsvp)

      conn
      |> login(attendee)
      |> visit("/my-huddlz")
      |> assert_has("h3.card-title", text: "I Am Going")
      |> refute_has("h3.card-title", text: "They Are Going")
      |> assert_has(".filters .chip", text: "Upcoming · 1")
    end
  end

  describe "card destinations" do
    test "card links to the huddl detail page", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Linked Show")
      rsvp!(huddl, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/my-huddlz")
      |> assert_has(~s(.grid .card[href="/groups/#{public_group.slug}/huddlz/#{huddl.id}"]))
    end
  end

  describe "Past filter sort" do
    test "newest first (most recently ended)", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      older =
        create_past_huddl(host, public_group,
          title: "Older Past Event",
          starts_at: DateTime.add(DateTime.utc_now(), -10, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -10, :day) |> DateTime.add(2, :hour)
        )

      newer =
        create_past_huddl(host, public_group,
          title: "Newer Past Event",
          starts_at: DateTime.add(DateTime.utc_now(), -1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -1, :day) |> DateTime.add(2, :hour)
        )

      rsvp!(older, attendee, :rsvp)
      rsvp!(newer, attendee, :rsvp)

      session =
        conn
        |> login(attendee)
        |> visit("/my-huddlz?filter=past")

      html = Phoenix.LiveViewTest.render(session.view)

      newer_idx = :binary.match(html, "Newer Past Event") |> elem(0)
      older_idx = :binary.match(html, "Older Past Event") |> elem(0)

      assert newer_idx < older_idx,
             "Newer event should appear before older event in past list"
    end
  end

  describe "pagination" do
    setup %{attendee: attendee, host: host, public_group: public_group} do
      # 22 attended upcoming → 2 pages of 20
      huddls =
        for i <- 1..22 do
          slug = String.pad_leading(Integer.to_string(i), 3, "0")

          h =
            create_huddl(host, public_group,
              title: "Huddl #{slug}",
              date: Date.add(Date.utc_today(), i),
              start_time: ~T[14:00:00]
            )

          rsvp!(h, attendee, :rsvp)
          h
        end

      %{huddls: huddls}
    end

    test "shows pagination when more than 20 results", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz")
      |> assert_has(".filters .chip", text: "Upcoming · 22")
      |> assert_has(".pagination .page-num", text: "2")
    end

    test "page 1 shows the soonest 20", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz")
      |> assert_has("h3.card-title", text: "Huddl 001")
      |> refute_has("h3.card-title", text: "Huddl 021")
    end

    test "page=2 shows the remaining 2", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz?page=2")
      |> assert_has("h3.card-title", text: "Huddl 021")
      |> assert_has("h3.card-title", text: "Huddl 022")
      |> refute_has("h3.card-title", text: "Huddl 001")
    end

    test "out-of-range ?page= clamps to last valid page", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/my-huddlz?page=999")
      |> assert_path("/my-huddlz", query_params: %{"page" => "2"})
    end
  end
end

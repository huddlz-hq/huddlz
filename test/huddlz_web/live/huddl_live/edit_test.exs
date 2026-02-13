defmodule HuddlzWeb.HuddlLive.EditTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication, only: [login: 2]
  import Mox

  alias Huddlz.Communities.Huddl

  require Ash.Query

  setup :verify_on_exit!

  describe "mount and authorization" do
    setup do
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      member = generate(user(role: :user))
      non_member = generate(user(role: :user))

      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

      huddl =
        generate(
          huddl(
            title: "Test Huddl",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            physical_location: "123 Main St, City"
          )
        )

      %{
        owner: owner,
        organizer: organizer,
        member: member,
        non_member: non_member,
        group: group,
        huddl: huddl
      }
    end

    test "owner can access huddl edit form", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

      assert_has(session, "h1", text: "Editing #{huddl.title}")
      assert_has(session, "#huddl-form")
    end

    test "organizer can access huddl edit form", %{
      conn: conn,
      organizer: organizer,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(organizer)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

      assert_has(session, "h1", text: "Editing #{huddl.title}")
      assert_has(session, "#huddl-form")
    end

    test "regular member cannot access huddl edit form", %{
      conn: conn,
      member: member,
      group: group,
      huddl: huddl
    } do
      conn
      |> login(member)
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
      |> assert_has("*", text: "You don't have permission to edit this huddl")
    end

    test "requires authentication", %{conn: conn, group: group, huddl: huddl} do
      conn
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
      |> assert_path("/sign-in")
    end
  end

  describe "form fields" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            title: "Test Huddl",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            physical_location: "123 Main St, City"
          )
        )

      %{owner: owner, group: group, huddl: huddl}
    end

    test "shows date/time/duration pickers instead of datetime-local", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

      assert_has(session, "input[name='form[date]'][type='date']")
      assert_has(session, "input[name='form[start_time]']")
      assert_has(session, "select[name='form[duration_minutes]']")

      # Should NOT have the old datetime-local inputs
      refute_has(session, "input[name='form[starts_at]'][type='datetime-local']")
      refute_has(session, "input[name='form[ends_at]'][type='datetime-local']")
    end

    test "pre-populates date/time/duration from existing huddl", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

      expected_date = DateTime.to_date(huddl.starts_at) |> Date.to_iso8601()
      assert_has(session, "input[name='form[date]'][value='#{expected_date}']")

      expected_duration =
        to_string(DateTime.diff(huddl.ends_at, huddl.starts_at, :minute))

      assert_has(
        session,
        "select[name='form[duration_minutes]'] option[value='#{expected_duration}'][selected]"
      )
    end

    test "pre-populates date/time/duration for recurring huddl", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      recurring_huddl =
        generate(
          huddl(
            title: "Recurring Huddl",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            physical_location: "456 Oak Ave",
            is_recurring: true,
            frequency: :weekly,
            repeat_until: Date.utc_today() |> Date.add(60)
          )
        )

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{recurring_huddl.id}/edit")

      expected_date = DateTime.to_date(recurring_huddl.starts_at) |> Date.to_iso8601()
      assert_has(session, "input[name='form[date]'][value='#{expected_date}']")

      expected_duration =
        to_string(DateTime.diff(recurring_huddl.ends_at, recurring_huddl.starts_at, :minute))

      assert_has(
        session,
        "select[name='form[duration_minutes]'] option[value='#{expected_duration}'][selected]"
      )

      # Recurring fields should also be shown
      assert_has(session, "*", text: "This is a recurring huddl")
    end

    test "shows all required form fields", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

      assert_has(session, "input[name='form[title]']")
      assert_has(session, "textarea[name='form[description]']")
      assert_has(session, "select[name='form[event_type]']")
    end

    test "shows calculated end time", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

      assert_has(session, "*", text: "Ends at:")
    end
  end

  describe "form submission" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            title: "Original Title",
            description: "Original description",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            physical_location: "123 Main St"
          )
        )

      %{owner: owner, group: group, huddl: huddl}
    end

    test "updates huddl title", %{conn: conn, owner: owner, group: group, huddl: huddl} do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
        |> fill_in("Title", with: "Updated Title")
        |> click_button("Save Huddl")

      assert_has(session, "*", text: "Huddl updated successfully!")

      updated_huddl =
        Huddl
        |> Ash.Query.filter(id == ^huddl.id)
        |> Ash.read_one!(actor: owner)

      assert updated_huddl.title == "Updated Title"
    end

    test "updates huddl with new date/time/duration", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      new_date = Date.utc_today() |> Date.add(5) |> Date.to_iso8601()

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
        |> fill_in("Date", with: new_date)
        |> fill_in("Start Time", with: "10:00")
        |> select("Duration", option: "1.5 hours")
        |> click_button("Save Huddl")

      assert_has(session, "*", text: "Huddl updated successfully!")

      updated_huddl =
        Huddl
        |> Ash.Query.filter(id == ^huddl.id)
        |> Ash.read_one!(actor: owner)

      assert DateTime.to_date(updated_huddl.starts_at) == Date.from_iso8601!(new_date)
      duration = DateTime.diff(updated_huddl.ends_at, updated_huddl.starts_at, :minute)
      assert duration == 90
    end
  end

  describe "address autocomplete" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            title: "Test Huddl",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            physical_location: "123 Main St"
          )
        )

      %{owner: owner, group: group, huddl: huddl}
    end

    test "shows address autocomplete for physical location", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

      assert_has(session, "#address-autocomplete")
      assert_has(session, "input[name='form[physical_location]']")
    end

    test "shows suggestions when typing in physical location", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      stub(Huddlz.MockPlaces, :autocomplete, fn
        "austin coffee", _token, _opts ->
          {:ok,
           [
             %{
               place_id: "p1",
               display_text: "Austin Coffee, Austin, TX, USA",
               main_text: "Austin Coffee",
               secondary_text: "Austin, TX, USA"
             }
           ]}

        _, _token, _opts ->
          {:ok, []}
      end)

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
      |> fill_in("Physical Location", with: "austin coffee")
      |> assert_has("button", text: "Austin Coffee")
    end

    test "selecting a suggestion preserves other form fields", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      stub(Huddlz.MockPlaces, :autocomplete, fn
        "austin coffee", _token, _opts ->
          {:ok,
           [
             %{
               place_id: "p1",
               display_text: "Austin Coffee, Austin, TX, USA",
               main_text: "Austin Coffee",
               secondary_text: "Austin, TX, USA"
             }
           ]}

        _, _token, _opts ->
          {:ok, []}
      end)

      expected_date = DateTime.to_date(huddl.starts_at) |> Date.to_iso8601()

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
      |> fill_in("Title", with: "My Updated Title")
      |> fill_in("Physical Location", with: "austin coffee")
      |> click_button("Austin Coffee")
      # Location should be populated
      |> assert_has(
        "input[name='form[physical_location]'][value='Austin Coffee, Austin, TX, USA']"
      )
      # Other form fields must be preserved
      |> assert_has("input[name='form[title]'][value='My Updated Title']")
      |> assert_has("input[name='form[date]'][value='#{expected_date}']")
    end

    test "selecting a suggestion populates the field", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      stub(Huddlz.MockPlaces, :autocomplete, fn
        "austin coffee", _token, _opts ->
          {:ok,
           [
             %{
               place_id: "p1",
               display_text: "Austin Coffee, Austin, TX, USA",
               main_text: "Austin Coffee",
               secondary_text: "Austin, TX, USA"
             }
           ]}

        _, _token, _opts ->
          {:ok, []}
      end)

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
      |> fill_in("Physical Location", with: "austin coffee")
      |> click_button("Austin Coffee")
      |> assert_has(
        "input[name='form[physical_location]'][value='Austin Coffee, Austin, TX, USA']"
      )
    end
  end
end

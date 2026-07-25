defmodule HuddlzWeb.HuddlLive.EditTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication, only: [login: 2]
  import Huddlz.Test.Helpers.LocationSelection
  import Phoenix.LiveViewTest

  alias Huddlz.Communities.Huddl

  require Ash.Query

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
      assert_has(session, "*", text: "Editing one date")
      assert_has(session, "button", text: "Whole series")
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
      assert_has(session, "input[name='form[event_type]'][type='radio']")
      assert_has(session, "fieldset.huddl-format-fieldset legend", text: "Huddl format")

      assert_has(
        session,
        ".toggle input[name='form[is_private]'][type='checkbox'][role='switch'][aria-checked='false']"
      )
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

  describe "recurring edit scope" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

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

      %{owner: owner, group: group, huddl: recurring_huddl}
    end

    test "defaults to instance scope on load", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

      assert_has(session, "*", text: "Editing one date")
      assert_has(session, "input[type='hidden'][name='form[edit_type]'][value='instance']")
      refute_has(session, "select[name='form[frequency]']")
      refute_has(session, "input[name='form[repeat_until]']")
    end

    test "clicking 'Whole series' flips scope and reveals series fields", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
        |> click_button("Whole series")

      assert_has(session, "*", text: "Editing every upcoming date")
      assert_has(session, "input[type='hidden'][name='form[edit_type]'][value='all']")
      assert_has(session, "select[name='form[frequency]']")
      assert_has(session, "input[name='form[repeat_until]']")
    end

    test "whole-series editing preserves an every-two-weeks cadence", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      every_other_week_huddl =
        create_recurring_huddl(owner, group,
          title: "Every Other Week Series",
          frequency: :every_two_weeks,
          repeat_until: Date.utc_today() |> Date.add(60)
        )

      session = open_whole_series_edit(conn, owner, group, every_other_week_huddl)

      assert_has(
        session,
        "select[name='form[frequency]'] option[value='every_two_weeks'][selected]"
      )

      save_whole_series(session)

      template =
        every_other_week_huddl
        |> Ash.reload!(actor: owner)
        |> Ash.load!(:huddl_template, actor: owner)
        |> Map.fetch!(:huddl_template)

      assert template.interval == 2
      assert template.unit == :week

      dates =
        every_other_week_huddl
        |> load_series_huddlz(owner)
        |> Enum.map(&DateTime.to_date(&1.starts_at))
        |> Enum.sort(Date)

      assert dates
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [first, second] -> Date.diff(second, first) == 14 end)
    end

    test "whole-series editing keeps virtual controls and their value", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      virtual_huddl =
        create_recurring_huddl(owner, group,
          title: "Virtual Series",
          event_type: :virtual,
          virtual_link: "https://meet.example.com/virtual-series"
        )

      session = open_whole_series_edit(conn, owner, group, virtual_huddl)

      assert_has(session, "#event-type-virtual[checked]")

      assert_has(
        session,
        "input[name='form[virtual_link]'][value='https://meet.example.com/virtual-series']"
      )

      refute_has(session, "#saved-location-picker")

      save_whole_series(session)

      assert Enum.all?(load_series_huddlz(virtual_huddl, owner), fn huddl ->
               huddl.event_type == :virtual and
                 huddl.virtual_link == "https://meet.example.com/virtual-series" and
                 is_nil(huddl.physical_location)
             end)
    end

    test "whole-series editing keeps hybrid controls and their values", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Community Studio",
            address: "456 Oak Ave",
            actor: owner
          )
        )

      hybrid_huddl =
        create_recurring_huddl(owner, group,
          title: "Hybrid Series",
          event_type: :hybrid,
          physical_location: location.address,
          virtual_link: "https://meet.example.com/hybrid-series"
        )

      session = open_whole_series_edit(conn, owner, group, hybrid_huddl)

      assert_has(session, "#event-type-hybrid[checked]")
      assert_has(session, "[data-testid='saved-location-display']", text: location.name)

      assert_has(
        session,
        "input[name='form[virtual_link]'][value='https://meet.example.com/hybrid-series']"
      )

      save_whole_series(session)

      assert Enum.all?(load_series_huddlz(hybrid_huddl, owner), fn huddl ->
               huddl.event_type == :hybrid and
                 huddl.virtual_link == "https://meet.example.com/hybrid-series" and
                 huddl.physical_location == location.address and
                 huddl.group_location_id == location.id
             end)
    end

    test "whole-series editing keeps in-person controls without requiring an online link", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Neighborhood Hall",
            address: "789 Main St",
            actor: owner
          )
        )

      in_person_huddl =
        create_recurring_huddl(owner, group,
          title: "In-person Series",
          event_type: :in_person,
          physical_location: location.address,
          virtual_link: nil
        )

      session = open_whole_series_edit(conn, owner, group, in_person_huddl)

      assert_has(session, "#event-type-in_person[checked]")
      assert_has(session, "[data-testid='saved-location-display']", text: location.name)
      refute_has(session, "input[name='form[virtual_link]']")

      save_whole_series(session)

      assert Enum.all?(load_series_huddlz(in_person_huddl, owner), fn huddl ->
               huddl.event_type == :in_person and
                 huddl.physical_location == location.address and
                 huddl.group_location_id == location.id and
                 is_nil(huddl.virtual_link)
             end)
    end

    test "whole-series format changes propagate to every huddl", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Original Venue",
            address: "123 Original St",
            actor: owner
          )
        )

      hybrid_huddl =
        create_recurring_huddl(owner, group,
          title: "Changing Format Series",
          event_type: :hybrid,
          physical_location: location.address,
          virtual_link: "https://meet.example.com/changed-series"
        )

      conn
      |> open_whole_series_edit(owner, group, hybrid_huddl)
      |> choose("Virtual")
      |> save_whole_series()

      assert Enum.all?(load_series_huddlz(hybrid_huddl, owner), fn huddl ->
               huddl.event_type == :virtual and
                 huddl.virtual_link == "https://meet.example.com/changed-series" and
                 is_nil(huddl.physical_location)
             end)
    end

    test "clicking 'Just this huddl' after 'Whole series' restores instance scope", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
        |> click_button("Whole series")
        |> click_button("Just this huddl")

      assert_has(session, "*", text: "Editing one date")
      assert_has(session, "input[type='hidden'][name='form[edit_type]'][value='instance']")
      refute_has(session, "select[name='form[frequency]']")
      refute_has(session, "input[name='form[repeat_until]']")
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
        |> click_button("Save changes")

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
        |> fill_in("Start time", with: "10:00")
        |> select("Duration", option: "1.5 hours")
        |> click_button("Save changes")

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

  describe "capacity validation" do
    setup do
      owner = generate(user(role: :user))
      member_a = generate(user(role: :user))
      member_b = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            title: "Capped",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            physical_location: "123 Main St",
            # Start unlimited; the generator otherwise randomly fills this with
            # a large integer half the time, breaking the post-validation assert.
            max_attendees: nil
          )
        )

      for actor <- [member_a, member_b] do
        huddl
        |> Ash.reload!()
        |> Ash.Changeset.for_update(:rsvp, %{}, actor: actor)
        |> Ash.update!()
      end

      %{owner: owner, group: group, huddl: huddl}
    end

    test "renders inline error when reducing capacity below current RSVPs", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
        |> fill_in("Max attendees", with: "1")
        |> click_button("Save changes")

      assert_path(session, ~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
      assert_has(session, "*", text: "cannot be less than the current RSVP count")

      reloaded =
        Huddl
        |> Ash.Query.filter(id == ^huddl.id)
        |> Ash.read_one!(actor: owner)

      assert reloaded.max_attendees == nil
    end

    test "clearing an invalid capacity restores unlimited capacity", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
        |> fill_in("Max attendees", with: "0")
        |> assert_has("#form_max_attendees-error-0", text: "Must be at least 1")
        |> fill_in("Max attendees", with: "")
        |> refute_has("input[name='form[max_attendees]'][value='0']")
        |> refute_has("#form_max_attendees-error-0")
        |> click_button("Save changes")

      assert_has(session, "*", text: "Huddl updated successfully!")

      reloaded =
        Huddl
        |> Ash.Query.filter(id == ^huddl.id)
        |> Ash.read_one!(actor: owner)

      assert is_nil(reloaded.max_attendees)
    end
  end

  describe "virtual link validation" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            title: "Virtual Huddl",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            event_type: :virtual,
            virtual_link: "https://meet.example.com/original"
          )
        )

      %{owner: owner, group: group, huddl: huddl}
    end

    test "shows a friendly inline error for a malformed link", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
      |> assert_has("input[name='form[virtual_link]'][type='text'][inputmode='url']")
      |> fill_in("Online link", with: "javascript:alert(1)")
      |> click_button("Save changes")
      |> assert_path(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
      |> assert_has(
        "input[name='form[virtual_link]'][aria-invalid='true'][aria-describedby='form_virtual_link-help form_virtual_link-error-0']"
      )
      |> assert_has(
        "#form_virtual_link-error-0",
        text: "Must be a valid web address starting with http:// or https://"
      )
    end
  end

  describe "saved location picker" do
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

    test "shows saved location picker for physical location", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

      assert_has(session, "#saved-location-picker")
    end

    test "switching to in-person shows location error only after a failed save", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      huddl =
        generate(
          huddl(
            title: "Virtual Huddl",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            event_type: :virtual,
            virtual_link: "https://example.com/meet"
          )
        )

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
      |> choose("In person")
      # Revealing the picker must not immediately flag the missing location
      |> refute_has("p.form-error", text: "is required for in-person huddlz")
      |> click_button("Save changes")
      |> assert_path(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
      |> assert_has("p.form-error", text: "is required for in-person huddlz")
    end

    test "selecting a saved location preserves other form fields", %{
      conn: conn,
      owner: owner,
      group: group,
      huddl: huddl
    } do
      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Austin Coffee",
            address: "Austin Coffee, Austin, TX, USA",
            latitude: 30.27,
            longitude: -97.74,
            actor: owner
          )
        )

      expected_date = DateTime.to_date(huddl.starts_at) |> Date.to_iso8601()

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")

      view
      |> form("#huddl-form", %{"form" => %{"title" => "My Updated Title"}})
      |> render_change()

      select_saved_location(view, location)

      # Location should be in selected state
      assert has_element?(view, "[data-testid='saved-location-selected']")

      # Other form fields must be preserved
      assert has_element?(view, "input[name='form[title]'][value='My Updated Title']")
      assert has_element?(view, "input[name='form[date]'][value='#{expected_date}']")

      view
      |> element("#huddl-form")
      |> render_submit()

      assert %Huddl{group_location_id: group_location_id} =
               Huddl
               |> Ash.Query.filter(id == ^huddl.id)
               |> Ash.read_one!(authorize?: false)

      assert group_location_id == location.id
    end
  end

  defp create_recurring_huddl(owner, group, attrs) do
    huddl_attrs =
      Keyword.merge(
        [
          group_id: group.id,
          creator_id: owner.id,
          actor: owner,
          is_recurring: true,
          frequency: :weekly,
          repeat_until: Date.utc_today() |> Date.add(60)
        ],
        attrs
      )

    recurring_huddl = generate(huddl(huddl_attrs))

    assert %{success: success_count} = Oban.drain_queue(queue: :default)
    assert success_count > 0

    recurring_huddl
  end

  defp open_whole_series_edit(conn, owner, group, huddl) do
    conn
    |> login(owner)
    |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit")
    |> click_button("Whole series")
  end

  defp save_whole_series(session) do
    session
    |> click_button("Save changes")
    |> assert_has("*", text: "Huddl updated successfully!")
  end

  defp load_series_huddlz(huddl, owner) do
    series_huddlz =
      Huddl
      |> Ash.Query.filter(huddl_template_id == ^huddl.huddl_template_id)
      |> Ash.read!(actor: owner)

    assert length(series_huddlz) > 1
    series_huddlz
  end
end

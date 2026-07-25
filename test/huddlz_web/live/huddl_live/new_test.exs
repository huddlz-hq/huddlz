defmodule HuddlzWeb.HuddlLive.NewTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Huddlz.Test.Helpers.LocationSelection
  import Mox
  import Phoenix.LiveViewTest

  import Huddlz.Test.Helpers.Authentication, only: [login: 2]

  alias Huddlz.Communities.Huddl

  setup :verify_on_exit!

  require Ash.Query

  describe "mount and authorization" do
    setup do
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      member = generate(user(role: :user))
      regular = generate(user(role: :user))
      non_member = generate(user(role: :user))

      {group, _} =
        generate_group_with_members(
          owner: owner,
          group: [is_public: true],
          members: [
            %{user: organizer, role: :organizer},
            %{user: member, role: :member}
          ]
        )

      %{
        owner: owner,
        organizer: organizer,
        member: member,
        regular: regular,
        non_member: non_member,
        group: group
      }
    end

    test "owner can access huddl creation form", %{conn: conn, owner: owner, group: group} do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")

      assert_has(session, "h1", text: "Schedule a huddl")
      assert_has(session, "#huddl-form")

      # The group name should be somewhere on the page
      assert session.conn.resp_body =~
               Phoenix.HTML.html_escape(to_string(group.name)) |> Phoenix.HTML.safe_to_string()
    end

    test "organizer can access huddl creation form", %{
      conn: conn,
      organizer: organizer,
      group: group
    } do
      session =
        conn
        |> login(organizer)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")

      assert_has(session, "h1", text: "Schedule a huddl")
      assert_has(session, "#huddl-form")

      # The group name should be somewhere on the page
      assert session.conn.resp_body =~
               Phoenix.HTML.html_escape(to_string(group.name)) |> Phoenix.HTML.safe_to_string()
    end

    test "regular member cannot access huddl creation form", %{
      conn: conn,
      member: member,
      group: group
    } do
      session =
        conn
        |> login(member)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")

      # Should redirect to group page
      assert_path(session, ~p"/groups/#{group.slug}")

      # Check flash message
      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~
               "You don't have permission to create huddlz for this group"
    end

    test "non-member cannot access huddl creation form", %{
      conn: conn,
      non_member: non_member,
      group: group
    } do
      session =
        conn
        |> login(non_member)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")

      # Should redirect to group page
      assert_path(session, ~p"/groups/#{group.slug}")

      # Check flash message
      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~
               "You don't have permission to create huddlz for this group"
    end

    test "redirects when group not found", %{conn: conn, owner: owner} do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{Ash.UUID.generate()}/huddlz/new")

      # Should redirect to the groups scope of /discover
      assert_path(session, ~p"/discover", query_params: %{"scope" => "groups"})

      # Check flash message
      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~ "Group not found"
    end

    test "requires authentication", %{conn: conn, group: group} do
      session =
        conn
        |> visit(~p"/groups/#{group.slug}/huddlz/new")

      # Should redirect to sign-in
      assert session.conn.request_path =~ "/sign-in"
    end
  end

  describe "form rendering" do
    setup do
      owner = generate(user(role: :user))
      public_group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      %{owner: owner, public_group: public_group, private_group: private_group}
    end

    test "shows all form fields", %{conn: conn, owner: owner, public_group: group} do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")

      assert_has(session, "input[name='form[title]']")
      assert_has(session, "textarea[name='form[description]']")
      # New date/time/duration fields
      assert_has(session, "input[name='form[date]'][type='date']")
      assert_has(session, "input[name='form[start_time]']")
      assert_has(session, "select[name='form[duration_minutes]']")
      assert_has(session, "input[name='form[event_type]'][type='radio']")
      assert_has(session, "fieldset.huddl-format-fieldset legend", text: "Huddl format")

      assert_has(
        session,
        ".event-type-option:has(label[for='event-type-in_person']) input#event-type-in_person[type='radio'][checked]"
      )

      assert_has(
        session,
        ".event-type-option:has(label[for='event-type-virtual']) input#event-type-virtual[type='radio']"
      )

      assert_has(
        session,
        ".toggle input[name='form[is_recurring]'][role='switch'][aria-checked='false']"
      )
    end

    test "shows 16:9 ratio guidance for cover image", %{
      conn: conn,
      owner: owner,
      public_group: group
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")

      assert_has(session, "*", text: "Drop a 16:9 image")
    end

    test "shows is_private checkbox for public groups", %{
      conn: conn,
      owner: owner,
      public_group: group
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")

      assert_has(
        session,
        ".toggle input[name='form[is_private]'][type='checkbox'][role='switch'][aria-checked='false']"
      )

      session
      |> check("Members only")
      |> assert_has(
        ".toggle input[name='form[is_private]'][role='switch'][aria-checked='true'][checked]"
      )
    end

    test "shows private huddl notice for private groups", %{
      conn: conn,
      owner: owner,
      private_group: group
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")

      refute session.conn.resp_body =~ ~s(input[name='form[is_private]'][type='checkbox'])
      assert session.conn.resp_body =~ "This will be a private huddl"
      assert session.conn.resp_body =~ "private groups can only create private huddlz"
    end
  end

  describe "dynamic field visibility" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      %{owner: owner, group: group}
    end

    test "shows physical location for in-person events", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/new")
      # Default should be in_person — SavedLocationPicker is shown
      |> assert_has("#saved-location-picker")
      |> refute_has("input[name='form[virtual_link]']")
    end

    test "shows virtual link for virtual events", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/new")
      # Change to virtual
      |> choose("Virtual")
      |> refute_has("#saved-location-picker")
      |> assert_has("input[name='form[virtual_link]'][type='text'][inputmode='url']")
    end

    test "shows both fields for hybrid events", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/new")
      # Change to hybrid
      |> choose("Hybrid")
      |> assert_has("#saved-location-picker")
      |> assert_has("input[name='form[virtual_link]']")
    end
  end

  describe "form submission" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      %{owner: owner, group: group}
    end

    test "creates huddl with valid data", %{conn: conn, owner: owner, group: group} do
      tomorrow = Date.utc_today() |> Date.add(1)
      date = Date.to_iso8601(tomorrow)
      time = "14:30"

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Title", with: "Test Huddl")
        |> fill_in("Description", with: "A test huddl description")
        |> fill_in("Date", with: date)
        |> fill_in("Start time", with: time)
        |> select("Duration", option: "2 hours")

      # Set physical location through autocomplete component
      select_physical_location(session.view, "123 Main St")

      session = click_button(session, "Schedule huddl")

      # Should redirect to group page
      assert_path(session, ~p"/groups/#{group.slug}")

      # Verify huddl was created
      huddl =
        Huddl
        |> Ash.Query.filter(title == "Test Huddl" and group_id == ^group.id)
        |> Ash.read_one!(actor: owner)

      assert huddl.description == "A test huddl description"
      assert huddl.physical_location == "123 Main St"
      assert huddl.event_type == :in_person
      assert huddl.is_private == false

      # Verify the calculated times
      assert DateTime.to_date(huddl.starts_at) == tomorrow
      # Verify duration is 2 hours
      duration_minutes = DateTime.diff(huddl.ends_at, huddl.starts_at, :minute)
      assert duration_minutes == 120
    end

    test "creates huddl with a capacity limit", %{conn: conn, owner: owner, group: group} do
      tomorrow = Date.utc_today() |> Date.add(1)
      date = Date.to_iso8601(tomorrow)

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Title", with: "Capped Huddl")
        |> fill_in("Description", with: "Limited seats")
        |> fill_in("Date", with: date)
        |> fill_in("Start time", with: "14:30")
        |> select("Duration", option: "2 hours")
        |> fill_in("Max attendees", with: "5")

      select_physical_location(session.view, "123 Main St")

      session
      |> click_button("Schedule huddl")
      |> assert_path(~p"/groups/#{group.slug}")

      huddl =
        Huddl
        |> Ash.Query.filter(title == "Capped Huddl" and group_id == ^group.id)
        |> Ash.read_one!(actor: owner)

      assert huddl.max_attendees == 5

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")
      |> assert_has("*", text: "1/5 spots filled")
    end

    test "creates an every-two-weeks recurring huddl", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      first_date = Date.utc_today() |> Date.add(1)
      repeat_until = Date.add(first_date, 43)

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Title", with: "Every Other Week Huddl")
        |> fill_in("Date", with: Date.to_iso8601(first_date))
        |> fill_in("Start time", with: "14:30")
        |> select("Duration", option: "2 hours")
        |> check("Recurring huddl")
        |> select("Frequency", option: "Every two weeks")
        |> fill_in("Repeat until", with: Date.to_iso8601(repeat_until))

      select_physical_location(session.view, "123 Main St")

      session
      |> click_button("Schedule huddl")
      |> assert_path(~p"/groups/#{group.slug}")

      template =
        Huddl
        |> Ash.Query.filter(title == "Every Other Week Huddl" and group_id == ^group.id)
        |> Ash.read_one!(actor: owner)
        |> Ash.load!(:huddl_template, actor: owner)
        |> Map.fetch!(:huddl_template)

      assert template.interval == 2
      assert template.unit == :week
    end

    test "creates private huddl for private group", %{conn: conn, owner: owner} do
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      tomorrow = Date.utc_today() |> Date.add(1)
      date = Date.to_iso8601(tomorrow)
      time = "14:30"

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{private_group.slug}/huddlz/new")
        # First change to virtual to show the virtual_link field
        |> choose("Virtual")
        |> fill_in("Title", with: "Private Group Huddl")
        |> fill_in("Description", with: "A huddl in a private group")
        |> fill_in("Date", with: date)
        |> fill_in("Start time", with: time)
        |> select("Duration", option: "2 hours")
        |> fill_in("Online link", with: "https://zoom.us/j/123456789")
        |> click_button("Schedule huddl")

      # Should redirect to group page
      assert_path(session, ~p"/groups/#{private_group.slug}")

      # Verify huddl was created as private
      huddl =
        Huddl
        |> Ash.Query.filter(title == "Private Group Huddl" and group_id == ^private_group.id)
        |> Ash.read_one!(actor: owner)

      assert huddl.is_private == true
      assert huddl.virtual_link == "https://zoom.us/j/123456789"
    end

    test "shows validation errors", %{conn: conn, owner: owner, group: group} do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        # Try to submit without filling required fields
        |> click_button("Schedule huddl")

      # Should still be on the same page
      assert_path(session, ~p"/groups/#{group.slug}/huddlz/new")

      # Should show validation error attached to the empty title field
      assert_has(session, "input#form_title + p.form-error")
    end

    test "shows a friendly inline error for a malformed virtual link", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/new")
      |> choose("Virtual")
      |> fill_in("Title", with: "Virtual Huddl")
      |> fill_in("Date", with: tomorrow)
      |> fill_in("Start time", with: "14:00")
      |> select("Duration", option: "1 hour")
      |> fill_in("Online link", with: "meet.example.com/no-scheme")
      |> click_button("Schedule huddl")
      |> assert_path(~p"/groups/#{group.slug}/huddlz/new")
      |> assert_has(
        "input[name='form[virtual_link]'][aria-invalid='true'][aria-describedby='form_virtual_link-help form_virtual_link-error-0']"
      )
      |> assert_has(
        "#form_virtual_link-error-0[role='alert']",
        text: "Must be a valid web address starting with http:// or https://"
      )
    end

    test "shows friendly capacity validation and allows clearing back to unlimited", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Max attendees", with: "0")
        |> assert_has(
          "input[name='form[max_attendees]'][aria-invalid='true'][aria-describedby='form_max_attendees-help form_max_attendees-error-0']"
        )
        |> assert_has("#form_max_attendees-error-0", text: "Must be at least 1")
        |> fill_in("Max attendees", with: "")
        |> refute_has("input[name='form[max_attendees]'][value='0']")
        |> refute_has("#form_max_attendees-error-0")
        |> fill_in("Title", with: "Unlimited Huddl")
        |> fill_in("Date", with: tomorrow)
        |> fill_in("Start time", with: "14:00")
        |> select("Duration", option: "1 hour")

      select_physical_location(session.view, "123 Main St")

      session
      |> click_button("Schedule huddl")
      |> assert_path(~p"/groups/#{group.slug}")

      huddl =
        Huddl
        |> Ash.Query.filter(title == "Unlimited Huddl" and group_id == ^group.id)
        |> Ash.read_one!(actor: owner)

      assert is_nil(huddl.max_attendees)
    end

    test "recurrence requirements are validated by the model instead of the browser", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> check("Recurring huddl")
        |> refute_has("select[name='form[frequency]'][required]")
        |> refute_has("input[name='form[repeat_until]'][required]")
        |> fill_in("Title", with: "Recurring Huddl")
        |> fill_in("Date", with: tomorrow)
        |> fill_in("Start time", with: "14:00")
        |> select("Duration", option: "1 hour")

      select_physical_location(session.view, "123 Main St")

      session
      |> click_button("Schedule huddl")
      |> assert_path(~p"/groups/#{group.slug}/huddlz/new")
      |> assert_has("#form_repeat_until-error-0", text: "is required for recurring huddlz")
    end

    test "shows physical location error when submitting in-person huddl without a location", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/huddlz/new")
      |> fill_in("Title", with: "Test Huddl")
      |> fill_in("Date", with: tomorrow)
      |> fill_in("Start time", with: "14:00")
      |> select("Duration", option: "1 hour")
      # Editing other fields must not surface the untouched location's error
      |> refute_has("p.form-error", text: "is required for in-person huddlz")
      # Leave event type as in-person (default), no location selected
      |> click_button("Schedule huddl")
      |> assert_path(~p"/groups/#{group.slug}/huddlz/new")
      |> assert_has(
        "#saved-location-picker-input[aria-invalid='true'][aria-describedby='form_physical_location-error-0']"
      )
      |> assert_has(
        "#form_physical_location-error-0[role='alert']",
        text: "is required for in-person huddlz"
      )
      # The error persists through later edits once the submit has failed
      |> fill_in("Title", with: "Test Huddl Again")
      |> assert_has("#form_physical_location-error-0", text: "is required for in-person huddlz")
    end

    test "hybrid huddl error shows under the missing virtual link, not the chosen location", %{
      conn: conn,
      owner: owner,
      group: group
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

      tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Title", with: "Hybrid Huddl")
        |> fill_in("Date", with: tomorrow)
        |> fill_in("Start time", with: "15:00")
        |> select("Duration", option: "1 hour")
        |> choose("Hybrid")

      session
      |> select_saved_location(location)
      |> click_button("Schedule huddl")
      |> assert_path(~p"/groups/#{group.slug}/huddlz/new")
      # Only the missing virtual link is flagged, right under its own input
      |> assert_has("input#form_virtual_link ~ p.form-error",
        text: "is required for hybrid huddlz"
      )
      |> assert_has("p.form-error", text: "is required for hybrid huddlz", count: 1)
    end

    test "selecting a saved location preserves other form fields", %{
      conn: conn,
      owner: owner,
      group: group
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

      tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Title", with: "My New Huddl")
        |> fill_in("Date", with: tomorrow)
        |> fill_in("Start time", with: "15:00")
        |> select("Duration", option: "2 hours")

      view = session.view

      # Simulate selecting a saved location
      select_saved_location(view, location)

      # Location should be in selected state
      assert has_element?(
               view,
               "[data-testid='saved-location-selected']"
             )

      # Other form fields must be preserved
      assert has_element?(view, "input[name='form[title]'][value='My New Huddl']")
      assert has_element?(view, "input[name='form[date]'][value='#{tomorrow}']")

      assert has_element?(
               view,
               "select[name='form[duration_minutes]'] option[value='120'][selected]"
             )

      view
      |> element("#huddl-form")
      |> render_submit()

      assert %Huddl{group_location_id: group_location_id} =
               Huddl
               |> Ash.Query.filter(title == "My New Huddl")
               |> Ash.read_one!(authorize?: false)

      assert group_location_id == location.id
    end

    test "validates form on change", %{conn: conn, owner: owner, group: group} do
      # PhoenixTest automatically triggers form validation on field changes
      # When we fill a field and then clear it, validation should show errors
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Title", with: "Test Title")
        # Clear the field to trigger validation
        |> fill_in("Title", with: "")

      # Check that the validation error renders in the same form-row as the title input
      assert_has(session, "input#form_title + p.form-error")
    end
  end

  describe "date/time/duration validation" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      %{owner: owner, group: group}
    end

    test "validates date must be in the future", %{conn: conn, owner: owner, group: group} do
      yesterday = Date.utc_today() |> Date.add(-1)
      date = Date.to_iso8601(yesterday)

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Title", with: "Test Huddl")
        |> fill_in("Date", with: date)
        |> fill_in("Start time", with: "14:30")
        |> select("Duration", option: "1 hour")

      select_physical_location(session.view, "123 Main St")

      session = click_button(session, "Schedule huddl")

      # Should still be on the same page with error
      assert_path(session, ~p"/groups/#{group.slug}/huddlz/new")

      # Should show validation error
      assert_has(
        session,
        "input[name='form[date]'][aria-invalid='true'][aria-describedby='form_date-error-0']"
      )

      assert_has(session, "#form_date-error-0", text: "must be in the future")
    end

    test "accepts manual time entry outside of 15-minute increments", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      tomorrow = Date.utc_today() |> Date.add(1)
      date = Date.to_iso8601(tomorrow)

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Title", with: "Test Huddl with Manual Time")
        |> fill_in("Date", with: date)
        # Enter a time that's not on a 15-minute increment
        |> fill_in("Start time", with: "09:47")
        |> select("Duration", option: "1 hour")

      select_physical_location(session.view, "123 Main St")

      session = click_button(session, "Schedule huddl")

      # Should redirect to group page (successful creation)
      assert_path(session, ~p"/groups/#{group.slug}")

      # Verify huddl was created with the exact time
      huddl =
        Huddl
        |> Ash.Query.filter(title == "Test Huddl with Manual Time" and group_id == ^group.id)
        |> Ash.read_one!(actor: owner)

      # Check that the time has minutes = 47
      assert huddl.starts_at.minute == 47
    end

    test "calculates end time correctly from duration", %{conn: conn, owner: owner, group: group} do
      tomorrow = Date.utc_today() |> Date.add(1)
      date = Date.to_iso8601(tomorrow)

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Title", with: "Test Duration Calculation")
        |> fill_in("Date", with: date)
        |> fill_in("Start time", with: "15:00")
        |> select("Duration", option: "1.5 hours")

      select_physical_location(session.view, "123 Main St")

      # Check that end time is displayed on the form
      assert session.conn.resp_body =~ "Ends at:"

      session = click_button(session, "Schedule huddl")

      # Should redirect to group page
      assert_path(session, ~p"/groups/#{group.slug}")

      # Verify huddl was created with correct duration
      huddl =
        Huddl
        |> Ash.Query.filter(title == "Test Duration Calculation" and group_id == ^group.id)
        |> Ash.read_one!(actor: owner)

      # Verify duration is 90 minutes (1.5 hours)
      duration_minutes = DateTime.diff(huddl.ends_at, huddl.starts_at, :minute)
      assert duration_minutes == 90
    end

    test "handles day boundary crossing for long durations", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      tomorrow = Date.utc_today() |> Date.add(1)
      date = Date.to_iso8601(tomorrow)

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/huddlz/new")
        |> fill_in("Title", with: "Test Day Boundary")
        |> fill_in("Date", with: date)
        |> fill_in("Start time", with: "23:00")
        |> select("Duration", option: "6 hours")

      select_physical_location(session.view, "123 Main St")

      session = click_button(session, "Schedule huddl")

      # Should redirect to group page
      assert_path(session, ~p"/groups/#{group.slug}")

      # Verify huddl was created
      huddl =
        Huddl
        |> Ash.Query.filter(title == "Test Day Boundary" and group_id == ^group.id)
        |> Ash.read_one!(actor: owner)

      # Verify end time is on the next day
      assert Date.diff(DateTime.to_date(huddl.ends_at), DateTime.to_date(huddl.starts_at)) == 1
      # Verify duration is 6 hours
      duration_minutes = DateTime.diff(huddl.ends_at, huddl.starts_at, :minute)
      assert duration_minutes == 360
    end
  end

  describe "create huddl button on group page" do
    setup do
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      member = generate(user(role: :user))

      {group, _} =
        generate_group_with_members(
          owner: owner,
          group: [is_public: true],
          members: [
            %{user: organizer, role: :organizer},
            %{user: member, role: :member}
          ]
        )

      %{
        owner: owner,
        organizer: organizer,
        member: member,
        group: group
      }
    end

    test "shows create button for owner", %{conn: conn, owner: owner, group: group} do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}")

      assert session.conn.resp_body =~ "Create Huddl"
      # Verify the Create Huddl link exists
      assert_has(session, "a", text: "Create Huddl")
    end

    test "shows create button for organizer", %{conn: conn, organizer: organizer, group: group} do
      session =
        conn
        |> login(organizer)
        |> visit(~p"/groups/#{group.slug}")

      assert session.conn.resp_body =~ "Create Huddl"
      # Verify the Create Huddl link exists
      assert_has(session, "a", text: "Create Huddl")
    end

    test "does not show create button for regular member", %{
      conn: conn,
      member: member,
      group: group
    } do
      session =
        conn
        |> login(member)
        |> visit(~p"/groups/#{group.slug}")

      refute session.conn.resp_body =~ "Create Huddl"
      refute_has(session, "a[href='/groups/#{group.slug}/huddlz/new']")
    end
  end

  # Helper to simulate selecting a physical location via SavedLocationPicker
  defp select_physical_location(view, text) do
    location = %Huddlz.Communities.GroupLocation{
      name: text,
      address: text,
      latitude: 30.27,
      longitude: -97.74
    }

    select_saved_location(view, location)
  end
end

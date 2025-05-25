defmodule HuddlzWeb.HuddlLive.NewTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator

  import Huddlz.Test.Helpers.Authentication, only: [login: 2]

  alias Huddlz.Communities.Huddl

  require Ash.Query

  describe "mount and authorization" do
    setup do
      owner = generate(user(role: :verified))
      organizer = generate(user(role: :verified))
      member = generate(user(role: :verified))
      regular = generate(user(role: :regular))
      non_member = generate(user(role: :verified))

      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      # Add organizer and member to group
      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

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
        |> visit(~p"/groups/#{group.id}/huddlz/new")
      
      assert_has(session, "h1", text: "Create New Huddl")
      assert_has(session, "#huddl-form")
      
      # The group name should be somewhere on the page
      assert session.conn.resp_body =~ Phoenix.HTML.html_escape(to_string(group.name)) |> Phoenix.HTML.safe_to_string()
    end

    test "organizer can access huddl creation form", %{
      conn: conn,
      organizer: organizer,
      group: group
    } do
      session = 
        conn
        |> login(organizer)
        |> visit(~p"/groups/#{group.id}/huddlz/new")
      
      assert_has(session, "h1", text: "Create New Huddl")
      assert_has(session, "#huddl-form")
      
      # The group name should be somewhere on the page
      assert session.conn.resp_body =~ Phoenix.HTML.html_escape(to_string(group.name)) |> Phoenix.HTML.safe_to_string()
    end

    test "regular member cannot access huddl creation form", %{
      conn: conn,
      member: member,
      group: group
    } do
      session = 
        conn
        |> login(member)
        |> visit(~p"/groups/#{group.id}/huddlz/new")
      
      # Should redirect to group page
      assert_path(session, ~p"/groups/#{group.id}")
      
      # Check flash message
      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~ "You don't have permission to create huddlz for this group"
    end

    test "non-member cannot access huddl creation form", %{
      conn: conn,
      non_member: non_member,
      group: group
    } do
      session = 
        conn
        |> login(non_member)
        |> visit(~p"/groups/#{group.id}/huddlz/new")
      
      # Should redirect to group page
      assert_path(session, ~p"/groups/#{group.id}")
      
      # Check flash message
      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~ "You don't have permission to create huddlz for this group"
    end

    test "redirects when group not found", %{conn: conn, owner: owner} do
      session = 
        conn
        |> login(owner)
        |> visit(~p"/groups/#{Ash.UUID.generate()}/huddlz/new")
      
      # Should redirect to groups index
      assert_path(session, ~p"/groups")
      
      # Check flash message
      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~ "Group not found"
    end

    test "requires authentication", %{conn: conn, group: group} do
      session = 
        conn
        |> visit(~p"/groups/#{group.id}/huddlz/new")
      
      # Should redirect to sign-in
      assert session.conn.request_path =~ "/sign-in"
    end
  end

  describe "form rendering" do
    setup do
      owner = generate(user(role: :verified))
      public_group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      %{owner: owner, public_group: public_group, private_group: private_group}
    end

    test "shows all form fields", %{conn: conn, owner: owner, public_group: group} do
      session = 
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.id}/huddlz/new")

      assert_has(session, "input[name='form[title]']")
      assert_has(session, "textarea[name='form[description]']")
      assert_has(session, "input[name='form[starts_at]'][type='datetime-local']")
      assert_has(session, "input[name='form[ends_at]'][type='datetime-local']")
      assert_has(session, "select[name='form[event_type]']")
    end

    test "shows is_private checkbox for public groups", %{
      conn: conn,
      owner: owner,
      public_group: group
    } do
      session = 
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.id}/huddlz/new")

      assert_has(session, "input[name='form[is_private]'][type='checkbox']")
      assert session.conn.resp_body =~ "Make this a private event"
    end

    test "shows private event notice for private groups", %{
      conn: conn,
      owner: owner,
      private_group: group
    } do
      session = 
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.id}/huddlz/new")

      refute session.conn.resp_body =~ ~s(input[name='form[is_private]'][type='checkbox'])
      assert session.conn.resp_body =~ "This will be a private event"
      assert session.conn.resp_body =~ "private groups can only create private events"
    end
  end

  describe "dynamic field visibility" do
    setup do
      owner = generate(user(role: :verified))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      %{owner: owner, group: group}
    end

    test "shows physical location for in-person events", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.id}/huddlz/new")
      # Default should be in_person
      |> assert_has("input[name='form[physical_location]']")
      |> refute_has("input[name='form[virtual_link]']")
    end

    test "shows virtual link for virtual events", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.id}/huddlz/new")
      # Change to virtual
      |> select("Event Type", option: "Virtual", exact: false)
      |> refute_has("input[name='form[physical_location]']")
      |> assert_has("input[name='form[virtual_link]']")
    end

    test "shows both fields for hybrid events", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.id}/huddlz/new")
      # Change to hybrid
      |> select("Event Type", option: "Hybrid (Both In-Person and Virtual)", exact: false)
      |> assert_has("input[name='form[physical_location]']")
      |> assert_has("input[name='form[virtual_link]']")
    end
  end

  describe "form submission" do
    setup do
      owner = generate(user(role: :verified))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      %{owner: owner, group: group}
    end

    test "creates huddl with valid data", %{conn: conn, owner: owner, group: group} do
      starts_at =
        DateTime.utc_now()
        |> DateTime.add(1, :day)
        |> DateTime.to_naive()
        |> NaiveDateTime.to_iso8601()
        |> String.slice(0..15)

      ends_at =
        DateTime.utc_now()
        |> DateTime.add(1, :day)
        |> DateTime.add(2, :hour)
        |> DateTime.to_naive()
        |> NaiveDateTime.to_iso8601()
        |> String.slice(0..15)

      session = 
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.id}/huddlz/new")
        |> fill_in("Title", with: "Test Huddl")
        |> fill_in("Description", with: "A test huddl description")
        |> fill_in("Start Date & Time", with: starts_at)
        |> fill_in("End Date & Time", with: ends_at)
        |> fill_in("Physical Location", with: "123 Main St")
        |> click_button("Create Huddl")

      # Should redirect to group page
      assert_path(session, ~p"/groups/#{group.id}")

      # Verify huddl was created
      huddl =
        Huddl
        |> Ash.Query.filter(title == "Test Huddl" and group_id == ^group.id)
        |> Ash.read_one!(actor: owner)

      assert huddl.description == "A test huddl description"
      assert huddl.physical_location == "123 Main St"
      assert huddl.event_type == :in_person
      assert huddl.is_private == false
    end

    test "creates private huddl for private group", %{conn: conn, owner: owner} do
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      starts_at =
        DateTime.utc_now()
        |> DateTime.add(1, :day)
        |> DateTime.to_naive()
        |> NaiveDateTime.to_iso8601()
        |> String.slice(0..15)

      ends_at =
        DateTime.utc_now()
        |> DateTime.add(1, :day)
        |> DateTime.add(2, :hour)
        |> DateTime.to_naive()
        |> NaiveDateTime.to_iso8601()
        |> String.slice(0..15)

      session = 
        conn
        |> login(owner)
        |> visit(~p"/groups/#{private_group.id}/huddlz/new")
        # First change to virtual to show the virtual_link field
        |> select("Event Type", option: "Virtual", exact: false)
        |> fill_in("Title", with: "Private Group Huddl")
        |> fill_in("Description", with: "A huddl in a private group")
        |> fill_in("Start Date & Time", with: starts_at)
        |> fill_in("End Date & Time", with: ends_at)
        |> fill_in("Virtual Meeting Link", with: "https://zoom.us/j/123456789")
        |> click_button("Create Huddl")

      # Should redirect to group page
      assert_path(session, ~p"/groups/#{private_group.id}")

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
        |> visit(~p"/groups/#{group.id}/huddlz/new")
        # Try to submit without filling required fields
        |> click_button("Create Huddl")

      # Should still be on the same page
      assert_path(session, ~p"/groups/#{group.id}/huddlz/new")
      
      # Should show validation error (checking for error class on input)
      assert_has(session, "input.input-error")
    end

    test "validates form on change", %{conn: conn, owner: owner, group: group} do
      # PhoenixTest automatically triggers form validation on field changes
      # When we fill a field and then clear it, validation should show errors
      session = 
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.id}/huddlz/new")
        |> fill_in("Title", with: "Test Title")
        |> fill_in("Title", with: "")  # Clear the field to trigger validation

      # Check for validation error class on the input
      assert_has(session, "input#form_title.input-error")
    end
  end

  describe "create huddl button on group page" do
    setup do
      owner = generate(user(role: :verified))
      organizer = generate(user(role: :verified))
      member = generate(user(role: :verified))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

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
        |> visit(~p"/groups/#{group.id}")

      assert session.conn.resp_body =~ "Create Huddl"
      assert_has(session, "a[href='/groups/#{group.id}/huddlz/new']")
    end

    test "shows create button for organizer", %{conn: conn, organizer: organizer, group: group} do
      session = 
        conn
        |> login(organizer)
        |> visit(~p"/groups/#{group.id}")

      assert session.conn.resp_body =~ "Create Huddl"
      assert_has(session, "a[href='/groups/#{group.id}/huddlz/new']")
    end

    test "does not show create button for regular member", %{
      conn: conn,
      member: member,
      group: group
    } do
      session = 
        conn
        |> login(member)
        |> visit(~p"/groups/#{group.id}")

      refute session.conn.resp_body =~ "Create Huddl"
      refute_has(session, "a[href='/groups/#{group.id}/huddlz/new']")
    end
  end
end

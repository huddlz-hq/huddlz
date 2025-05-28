defmodule CreateHuddlSteps do
  use Cucumber, feature: "create_huddl.feature"
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  alias Huddlz.Communities.Huddl
  require Ash.Query

  @tomorrow DateTime.utc_now() |> DateTime.add(1, :day)

  # Background steps - users and groups
  defstep "the following users exist:", context do
    users =
      context.datatable.maps
      |> Enum.map(fn user_data ->
        role =
          case user_data["role"] do
            "verified" -> :verified
            "regular" -> :regular
            "admin" -> :admin
            _ -> :regular
          end

        generate(
          user(
            email: user_data["email"],
            display_name: user_data["display_name"],
            role: role
          )
        )
      end)

    {:ok, Map.put(context, :users, users)}
  end

  defstep "the following groups exist:", context do
    groups =
      context.datatable.maps
      |> Enum.map(fn group_data ->
        owner_email = group_data["owner_email"]

        owner =
          Enum.find(context.users, fn u ->
            to_string(u.email) == owner_email
          end)

        is_public = group_data["is_public"] == "true"

        if owner do
          generate(
            group(
              name: group_data["name"],
              owner_id: owner.id,
              is_public: is_public,
              actor: owner
            )
          )
        else
          raise "Owner not found for email: #{owner_email}"
        end
      end)

    {:ok, Map.put(context, :groups, groups)}
  end

  defstep "the following group memberships exist:", context do
    memberships =
      context.datatable.maps
      |> Enum.map(fn membership_data ->
        user_email = membership_data["user_email"]
        group_name = membership_data["group_name"]

        role =
          case membership_data["role"] do
            "organizer" -> :organizer
            "member" -> :member
            _ -> :member
          end

        user =
          Enum.find(context.users, fn u ->
            to_string(u.email) == user_email
          end)

        group =
          Enum.find(context.groups, fn g ->
            g && to_string(g.name) == group_name
          end)

        if user && group do
          # Find the owner to act as the actor for adding members
          owner = Enum.find(context.users, &(&1.id == group.owner_id))

          generate(
            group_member(
              group_id: group.id,
              user_id: user.id,
              role: role,
              actor: owner
            )
          )
        else
          nil
        end
      end)

    {:ok, Map.put(context, :memberships, memberships)}
  end

  # Authentication step
  defstep "I am signed in as {string}", context do
    email = List.first(context.args)

    user =
      Enum.find(context.users, fn u ->
        to_string(u.email) == email
      end)

    # Sign in the user using the authentication helper
    conn = login(context.conn, user)

    # Create a PhoenixTest session
    session = conn |> visit("/")

    {:ok, Map.merge(context, %{conn: conn, session: session, current_user: user})}
  end

  # Navigation steps
  defstep "I visit the {string} group page", context do
    group_name = List.first(context.args)
    groups = Map.get(context, :groups, [])

    group =
      Enum.find(groups, fn g ->
        g && to_string(g.name) == group_name
      end)

    if !group do
      raise "Group not found: #{group_name}. Available groups: #{inspect(Enum.map(groups, & &1.name))}"
    end

    session = context.session |> visit("/groups/#{group.slug}")

    {:ok, Map.merge(context, %{session: session, current_group: group})}
  end

  defstep "I visit the new huddl page for {string}", context do
    group_name = List.first(context.args)

    group =
      Enum.find(context.groups, fn g ->
        g && to_string(g.name) == group_name
      end)

    session = context.session |> visit("/groups/#{group.slug}/huddlz/new")

    {:ok, Map.merge(context, %{session: session, current_group: group})}
  end

  defstep "I try to visit the new huddl page for {string}", context do
    group_name = List.first(context.args)

    group =
      Enum.find(context.groups, fn g ->
        g && to_string(g.name) == group_name
      end)

    # PhoenixTest handles redirects automatically, so we just visit
    session = context.session |> visit("/groups/#{group.slug}/huddlz/new")

    # Check if we're on the new huddl page or got redirected
    # If we can't see "Create New Huddl", we were probably redirected
    has_form =
      try do
        assert_has(session, "*", text: "Create New Huddl")
        true
      rescue
        _ -> false
      end

    if has_form do
      {:ok, Map.merge(context, %{session: session, current_group: group})}
    else
      {:ok,
       Map.merge(context, %{
         session: session,
         redirected: true,
         current_group: group
       })}
    end
  end

  # Visibility checks
  defstep "I should see a {string} button", context do
    button_text = List.first(context.args)
    # Check for either a button or a link with the text
    session = assert_has(context.session, "*", text: button_text)
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I should not see a {string} button", context do
    button_text = List.first(context.args)
    # Check that neither a button nor a link with the text exists
    session = refute_has(context.session, "*", text: button_text)
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I click {string}", context do
    button_text = List.first(context.args)

    # Try to click as a link first, then as a button
    session =
      try do
        context.session |> click_link(button_text)
      rescue
        _ -> context.session |> click_button(button_text)
      end

    {:ok, Map.put(context, :session, session)}
  end

  defstep "I should be on the new huddl page for {string}", context do
    group_name = List.first(context.args)

    # Check that we're on the new huddl page
    session = context.session
    session = assert_has(session, "*", text: "Create New Huddl")
    session = assert_has(session, "*", text: group_name)

    {:ok, Map.put(context, :session, session)}
  end

  # Form interaction steps
  defstep "I fill in the huddl form with:", context do
    form_data =
      context.datatable.maps
      |> Enum.reduce(%{}, fn field_data, acc ->
        field = field_data["Field"]
        value = field_data["Value"]

        case field do
          "Title" ->
            Map.put(acc, "title", value)

          "Description" ->
            Map.put(acc, "description", value)

          "Start Date & Time" ->
            start_time = parse_relative_time(value)
            Map.put(acc, "starts_at", DateTime.to_iso8601(start_time))

          "End Date & Time" ->
            end_time = parse_relative_time(value)
            Map.put(acc, "ends_at", DateTime.to_iso8601(end_time))

          "Event Type" ->
            event_type =
              case value do
                "In-Person" -> "in_person"
                "Virtual" -> "virtual"
                "Hybrid" -> "hybrid"
                _ -> "in_person"
              end

            Map.put(acc, "event_type", event_type)

          "Physical Location" ->
            Map.put(acc, "physical_location", value)

          "Virtual Link" ->
            Map.put(acc, "virtual_link", value)
        end
      end)

    {:ok, Map.put(context, :form_data, form_data)}
  end

  defstep "I submit the form", context do
    form_data = Map.get(context, :form_data, %{})
    session = context.session

    # First, select the event type if provided to ensure proper field visibility
    session =
      if form_data["event_type"] do
        event_type_label =
          case form_data["event_type"] do
            "in_person" -> "In-Person"
            "virtual" -> "Virtual"
            "hybrid" -> "Hybrid (Both In-Person and Virtual)"
            _ -> "In-Person"
          end

        # We need to select the event type first
        select(session, "Event Type", option: event_type_label, exact: false)
      else
        session
      end

    # Fill in the form data
    session =
      Enum.reduce(form_data, session, fn {field, value}, session ->
        case field do
          "title" -> fill_in(session, "Title", with: value, exact: false)
          "description" -> fill_in(session, "Description", with: value, exact: false)
          "physical_location" -> fill_in(session, "Physical Location", with: value, exact: false)
          "virtual_link" -> fill_in(session, "Virtual Meeting Link", with: value, exact: false)
          "starts_at" -> fill_in(session, "Start Date & Time", with: value, exact: false)
          "ends_at" -> fill_in(session, "End Date & Time", with: value, exact: false)
          # Already handled above
          "event_type" -> session
          _ -> session
        end
      end)

    # Submit the form
    session = click_button(session, "Create Huddl")

    {:ok, Map.put(context, :session, session)}
  end

  defstep "I submit the form without filling it", context do
    # Just click submit without filling anything
    session = click_button(context.session, "Create Huddl")

    {:ok, Map.put(context, :session, session)}
  end

  # Field visibility steps
  defstep "I should see {string} field", context do
    field_label = List.first(context.args)
    session = assert_has(context.session, "label", text: field_label)
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I should not see {string} field", context do
    field_label = List.first(context.args)
    session = refute_has(context.session, "label", text: field_label)
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I select {string} from {string}", context do
    [value, field] = context.args
    session = select(context.session, field, option: value, exact: false)
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I should not see a checkbox for {string}", context do
    label = List.first(context.args)
    session = refute_has(context.session, "input[type='checkbox']")
    session = refute_has(session, "*", text: label)
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I should see {string}", context do
    text = List.first(context.args)
    session = assert_has(context.session, "*", text: text)
    {:ok, Map.put(context, :session, session)}
  end

  # Redirection and result steps
  defstep "I should be redirected to the {string} group page", context do
    group_name = List.first(context.args)

    # Check that we're on the group page
    session = assert_has(context.session, "*", text: group_name)

    {:ok, Map.put(context, :session, session)}
  end

  defstep "the huddl should be created as private", context do
    # Wait a moment for any async operations to complete
    Process.sleep(100)

    # Find the most recently created huddl using the correct actor
    huddl =
      Huddl
      |> Ash.Query.filter(title == "Private Meeting")
      |> Ash.read_one!(actor: context.current_user, authorize?: true)

    assert huddl != nil, "Huddl 'Private Meeting' was not created"
    assert huddl.is_private == true
    {:ok, context}
  end

  defstep "I should see validation errors for required fields", context do
    # When form validation fails, we should see error messages
    session = context.session
    # Check for common validation error indicators
    # Ash Framework typically shows "is required" for required fields
    session = assert_has(session, "*", text: "is required")

    {:ok, Map.put(context, :session, session)}
  end

  defstep "I should remain on the new huddl page", context do
    # Check that we're still on the new huddl page
    session = assert_has(context.session, "*", text: "Create New Huddl")
    {:ok, Map.put(context, :session, session)}
  end

  # Helper functions
  defp parse_relative_time("tomorrow at " <> time) do
    [hour_str, minute_str, period] =
      case String.split(time, ~r/[:\s]+/) do
        [h, m, p] -> [h, m, p]
        [h, p] -> [h, "00", p]
      end

    hour = String.to_integer(hour_str)
    minute = String.to_integer(minute_str)

    # Convert to 24-hour format
    hour =
      cond do
        period == "PM" and hour != 12 -> hour + 12
        period == "AM" and hour == 12 -> 0
        true -> hour
      end

    @tomorrow
    |> DateTime.add(hour, :hour)
    |> DateTime.add(minute, :minute)
  end
end

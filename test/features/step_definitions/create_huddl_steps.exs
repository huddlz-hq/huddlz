defmodule CreateHuddlSteps do
  use Cucumber.StepDefinition
  import Huddlz.Generator
  import PhoenixTest
  import ExUnit.Assertions
  alias Huddlz.Communities.Huddl
  require Ash.Query

  @tomorrow DateTime.utc_now() |> DateTime.add(1, :day)

  # Group-specific steps
  step "the following groups exist:", context do
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

    Map.put(context, :groups, groups)
  end

  step "the following group memberships exist:", context do
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

    Map.put(context, :memberships, memberships)
  end

  # Navigation steps specific to groups and huddlz
  step "I visit the {string} group page", %{args: [group_name]} = context do
    groups = Map.get(context, :groups, [])

    group =
      Enum.find(groups, fn g ->
        g && to_string(g.name) == group_name
      end)

    if !group do
      raise "Group not found: #{group_name}. Available groups: #{inspect(Enum.map(groups, & &1.name))}"
    end

    session = context[:session] || context[:conn] || Phoenix.ConnTest.build_conn()
    session = visit(session, "/groups/#{group.slug}")

    context
    |> Map.merge(%{session: session, conn: session})
    |> Map.put(:current_group, group)
  end

  step "I visit the new huddl page for {string}", %{args: [group_name]} = context do
    group =
      Enum.find(context.groups, fn g ->
        g && to_string(g.name) == group_name
      end)

    session = context[:session] || context[:conn]
    session = visit(session, "/groups/#{group.slug}/huddlz/new")

    context
    |> Map.merge(%{session: session, conn: session})
    |> Map.put(:current_group, group)
  end

  step "I try to visit the new huddl page for {string}", %{args: [group_name]} = context do
    group =
      Enum.find(context.groups, fn g ->
        g && to_string(g.name) == group_name
      end)

    session = context[:session] || context[:conn]
    session = visit(session, "/groups/#{group.slug}/huddlz/new")

    # Check if we're on the new huddl page or got redirected
    has_form =
      try do
        assert_has(session, "*", text: "Create New Huddl")
        true
      rescue
        _ -> false
      end

    if has_form do
      context
      |> Map.merge(%{session: session, conn: session})
      |> Map.put(:current_group, group)
    else
      context
      |> Map.merge(%{session: session, conn: session})
      |> Map.put(:redirected, true)
      |> Map.put(:current_group, group)
    end
  end

  # Huddl-specific visibility checks
  step "I should see a {string} button", %{args: [button_text]} = context do
    session = context[:session] || context[:conn]
    # Try to find either a link or button with the text
    try do
      assert_has(session, "a", text: button_text)
    rescue
      _ -> assert_has(session, "button", text: button_text)
    end

    context
  end

  step "I should not see a {string} button", %{args: [button_text]} = context do
    session = context[:session] || context[:conn]
    refute_has(session, "button", text: button_text)
    context
  end

  step "I should be on the new huddl page for {string}", %{args: [group_name]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: "Create New Huddl")
    assert_has(session, "*", text: group_name)
    context
  end

  # Form interaction steps
  step "I fill in the huddl form with:", context do
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

          "Frequency" ->
            Map.put(acc, "frequency", value)

          "Repeat Until" ->
            repeat_until = parse_relative_time(value)
            Map.put(acc, "repeat_until", DateTime.to_iso8601(repeat_until))
        end
      end)

    Map.put(context, :form_data, form_data)
  end

  step "I submit the form", context do
    form_data = Map.get(context, :form_data, %{})
    session = context[:session] || context[:conn]

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
          "frequency" -> select(session, "Frequency", option: value, exact: false)
          "repeat_until" -> fill_in(session, "Repeat Until", with: value, exact: false)
          # Already handled above
          "event_type" -> session
          _ -> session
        end
      end)

    # Submit the form
    session = click_button(session, "Create Huddl")

    Map.merge(context, %{session: session, conn: session})
  end

  step "I submit the form without filling it", context do
    session = context[:session] || context[:conn]
    session = click_button(session, "Create Huddl")
    Map.merge(context, %{session: session, conn: session})
  end

  # Field visibility steps
  step "I should see {string} field", %{args: [field_label]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "label", text: field_label)
    context
  end

  step "I should not see {string} field", %{args: [field_label]} = context do
    session = context[:session] || context[:conn]
    refute_has(session, "label", text: field_label)
    context
  end

  step "I should not see a checkbox for {string}", %{args: [label]} = context do
    session = context[:session] || context[:conn]
    refute_has(session, "*", text: label)
    context
  end

  # Redirection and result steps
  step "I should be redirected to the {string} group page", %{args: [group_name]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: group_name)
    context
  end

  step "the huddl {string} should be created {int} times", %{args: [text, count]} = context do
    # Wait a moment for any async operations to complete
    Process.sleep(100)

    huddlz =
      Huddl
      |> Ash.Query.filter(title == ^text)
      |> Ash.read!(actor: context.current_user, authorize?: true)

    assert length(huddlz) == count, "Expected #{count} huddlz, got #{length(huddlz)}"

    context
  end

  step "the huddl should be created as private", context do
    # Wait a moment for any async operations to complete
    Process.sleep(100)

    # Find the most recently created huddl using the correct actor
    huddl =
      Huddl
      |> Ash.Query.filter(title == "Private Meeting")
      |> Ash.read_one!(actor: context.current_user, authorize?: true)

    assert huddl != nil, "Huddl 'Private Meeting' was not created"
    assert huddl.is_private == true
    context
  end

  step "I should see validation errors for required fields", context do
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: "is required")
    context
  end

  step "I should remain on the new huddl page", context do
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: "Create New Huddl")
    context
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

  defp parse_relative_time("two months") do
    DateTime.utc_now() |> DateTime.add(60, :day)
  end

  defp parse_relative_time("three months") do
    DateTime.utc_now() |> DateTime.add(90, :day)
  end
end

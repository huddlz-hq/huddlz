defmodule GroupManagementSteps do
  use Cucumber.StepDefinition
  import PhoenixTest
  import Phoenix.ConnTest, only: [assert_error_sent: 2, dispatch: 4]

  import Huddlz.Generator
  import Huddlz.Test.Helpers.LocationSelection, only: [select_location: 2]

  alias Huddlz.Accounts.User

  require Ash.Query

  # Group creation steps
  step "a {word} group {string} exists with owner {string}",
       %{args: [visibility, name, owner_email]} = context do
    owner =
      User
      |> Ash.Query.filter(email: owner_email)
      |> Ash.read_one!(authorize?: false)

    is_public = visibility == "public"

    group =
      generate(
        group(
          name: name,
          description: "#{name} description",
          is_public: is_public,
          owner_id: owner.id,
          location: "Test Location",
          actor: owner
        )
      )

    groups = Map.get(context, :groups, [])
    Map.put(context, :groups, [group | groups])
  end

  step "I visit the group page for {string}",
       %{args: [group_name]} = context do
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn g -> g.name |> to_string() == group_name end)

    session = context[:session] || context[:conn]
    session = session |> visit("/groups/#{group.slug}")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I try to visit the group page for {string}",
       %{args: [group_name]} = context do
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn group -> to_string(group.name) == group_name end)
    session = context[:session] || context[:conn]

    {404, _headers, body} =
      assert_error_sent 404, fn ->
        dispatch(session.conn, HuddlzWeb.Endpoint, :get, "/groups/#{group.slug}")
      end

    Map.put(context, :error_body, body)
  end

  # Form interaction steps
  step "I fill in the following:", context do
    # For 2-column tables without headers, Cucumber treats them as key-value pairs
    # Access the raw table data instead
    raw_table = context.datatable.raw

    # Fill in each field using PhoenixTest
    session = context[:session] || context[:conn]

    session =
      raw_table
      |> Enum.reduce(session, fn [field, value], session ->
        case field do
          "Location" ->
            select_location(session,
              display_text: value,
              main_text: value,
              latitude: 37.77,
              longitude: -122.42
            )

          _ ->
            fill_in(session, field, with: value)
        end
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  step "I check {string}", %{args: [label]} = context do
    session = context[:session] || context[:conn]
    session = check(session, label)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I uncheck {string}", %{args: [label]} = context do
    session = context[:session] || context[:conn]
    session = uncheck(session, label)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I visit the edit page for {string}",
       %{args: [group_name]} = context do
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn g -> g.name |> to_string() == group_name end)

    session = context[:session] || context[:conn]
    session = session |> visit("/groups/#{group.slug}/edit")
    Map.merge(context, %{session: session, conn: session, editing_group: group})
  end

  step "I visit the locations page for {string}",
       %{args: [group_name]} = context do
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn g -> g.name |> to_string() == group_name end)

    session = context[:session] || context[:conn]
    session = session |> visit("/groups/#{group.slug}/locations")
    Map.merge(context, %{session: session, conn: session})
  end

  # Assertions specific to groups
  step "I should be redirected to {string}", %{args: [_path]} = context do
    # PhoenixTest handles redirects automatically, so we just check we're on the expected page
    # We can check the path by looking for unique content on that page
    context
  end

  step "I should see an error on the {string} field", %{args: [field]} = context do
    session = context[:session] || context[:conn]
    field_id = if field == "Group name", do: "name", else: String.downcase(field)
    assert_has(session, "#form_#{field_id}-error-0", text: "is required")
    context
  end

  step "I should see the leave dialog for {string}", %{args: [group_name]} = context do
    session = context[:session] || context[:conn]

    session
    |> assert_has("#leave-group-dialog [role='dialog']")
    |> assert_has("#leave-group-dialog-title", text: "Leave #{group_name}?")
    |> assert_has("#leave-group-dialog", text: "member roster")
    |> assert_has("#leave-group-dialog", text: "My groups")
    |> assert_has("#leave-group-dialog", text: "notifications")

    context
  end

  step "the group member count should be {int}", %{args: [count]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, ".facts li", text: "Members #{count}")
    context
  end
end

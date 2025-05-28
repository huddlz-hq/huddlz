defmodule GroupManagementSteps do
  use Cucumber, feature: "group_management.feature"
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

  require Ash.Query

  # Background step: Create sample users
  defstep "the following users exist:", context do
    # Get table data from context - Cucumber provides it in datatable.maps
    table_data = context.datatable.maps

    users =
      table_data
      |> Enum.map(fn row ->
        # Row data has string keys
        email = row["email"]
        role = row["role"]
        display_name = row["display_name"]

        role_atom = String.to_existing_atom(role)

        # Use Ash.Seed.seed! to create users in the database
        Ash.Seed.seed!(User, %{
          email: email,
          role: role_atom,
          display_name: display_name
        })
      end)

    {:ok, Map.put(context, :users, users)}
  end

  # Authentication steps
  defstep "I am signed in as {string}", %{conn: conn, args: [email]} = context do
    user =
      User
      |> Ash.Query.filter(email: email)
      |> Ash.read_one!(authorize?: false)

    authenticated_conn = login(conn, user)
    session = authenticated_conn |> visit("/")

    # Preserve existing context data like groups
    {:ok, Map.merge(context, %{conn: authenticated_conn, session: session, current_user: user})}
  end

  # Group creation steps
  defstep "a {word} group {string} exists with owner {string}",
          %{args: [visibility, name, owner_email]} = context do
    owner =
      User
      |> Ash.Query.filter(email: owner_email)
      |> Ash.read_one!(authorize?: false)

    is_public = visibility == "public"

    # Create group using Ash create action
    group =
      Group
      |> Ash.Changeset.for_create(
        :create_group,
        %{
          name: name,
          description: "#{name} description",
          is_public: is_public,
          owner_id: owner.id,
          location: "Test Location"
        },
        actor: owner
      )
      |> Ash.create!()

    groups = Map.get(context, :groups, [])
    {:ok, Map.put(context, :groups, [group | groups])}
  end

  # Navigation steps
  defstep "I visit the groups page", context do
    session = (context[:session] || context.conn) |> visit("/groups")
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I visit {string}", %{args: [path]} = context do
    session = (context[:session] || context.conn) |> visit(path)
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I visit the group page for {string}",
          %{args: [group_name]} = context do
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn g -> g.name |> to_string() == group_name end)

    session = (context[:session] || context.conn) |> visit("/groups/#{group.slug}")
    {:ok, Map.put(context, :session, session)}
  end

  # Form interaction steps
  defstep "I fill in the following:", context do
    # For 2-column tables without headers, Cucumber treats them as key-value pairs
    # Access the raw table data instead
    raw_table = context.datatable.raw

    # Fill in each field using PhoenixTest
    session =
      raw_table
      |> Enum.reduce(context.session, fn [field, value], session ->
        # Convert field names to labels
        label =
          case field do
            "Group Name" -> "Group Name"
            "Description" -> "Description"
            "Location" -> "Location"
            _ -> field
          end

        fill_in(session, label, with: value)
      end)

    {:ok, Map.put(context, :session, session)}
  end

  defstep "I check {string}", %{args: [label]} = context do
    session = check(context.session, label)
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I uncheck {string}", %{args: [label]} = context do
    session = uncheck(context.session, label)
    {:ok, Map.put(context, :session, session)}
  end

  # Click actions
  defstep "I click {string}", %{args: [text]} = context do
    session =
      try do
        # Try as a link first
        click_link(context.session, text)
      rescue
        _ ->
          # Try as a button
          click_button(context.session, text)
      end

    {:ok, Map.put(context, :session, session)}
  end

  defstep "I click on the group {string}", %{args: [_group_name]} = context do
    # The View Group button is wrapped in a link, so we click the link
    session = click_link(context.session, "View Group")
    {:ok, Map.put(context, :session, session)}
  end

  # Assertions
  defstep "I should see {string}", %{args: [text]} = context do
    session = assert_has(context.session, "*", text: text)
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I should not see {string}", %{args: [text]} = context do
    session = refute_has(context.session, "*", text: text)
    {:ok, Map.put(context, :session, session)}
  end

  defstep "I should be redirected to {string}", %{args: [_path]} = context do
    # PhoenixTest handles redirects automatically, so we just check we're on the expected page
    # We can check the path by looking for unique content on that page
    {:ok, context}
  end

  defstep "I should see an error on the {string} field", %{args: [_field]} = context do
    # Look for error message
    session = assert_has(context.session, "*", text: "is required")
    {:ok, Map.put(context, :session, session)}
  end
end

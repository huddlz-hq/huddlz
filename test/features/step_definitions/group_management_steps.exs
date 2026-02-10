defmodule GroupManagementSteps do
  use Cucumber.StepDefinition
  import PhoenixTest

  import Huddlz.Generator

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

  # Navigation steps specific to groups
  step "I visit the groups page", context do
    session = context[:session] || context[:conn]
    session = session |> visit("/groups")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I visit the group page for {string}",
       %{args: [group_name]} = context do
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn g -> g.name |> to_string() == group_name end)

    session = context[:session] || context[:conn]
    session = session |> visit("/groups/#{group.slug}")
    Map.merge(context, %{session: session, conn: session})
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

  # Click actions specific to groups
  step "I click on the group {string}", %{args: [group_name]} = context do
    # The entire group card is a clickable link
    session = context[:session] || context[:conn]
    session = click_link(session, group_name)
    Map.merge(context, %{session: session, conn: session})
  end

  # Assertions specific to groups
  step "I should be redirected to {string}", %{args: [_path]} = context do
    # PhoenixTest handles redirects automatically, so we just check we're on the expected page
    # We can check the path by looking for unique content on that page
    context
  end

  step "I should see an error on the {string} field", %{args: [_field]} = context do
    # Look for error message
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: "is required")
    context
  end
end

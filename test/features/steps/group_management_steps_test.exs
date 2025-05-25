defmodule GroupManagementSteps do
  use Cucumber, feature: "group_management.feature"
  use HuddlzWeb.WallabyCase

  alias AshAuthentication.Info
  alias AshAuthentication.Strategy.MagicLink
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
  defstep "I am signed in as {string}", %{session: session, args: [email]} = context do
    user =
      User
      |> Ash.Query.filter(email: email)
      |> Ash.read_one!(authorize?: false)

    # Generate a magic link token for the user
    strategy = Info.strategy!(User, :magic_link)
    {:ok, token} = MagicLink.request_token_for(strategy, user)

    # Visit the magic link URL directly
    magic_link_url = "/auth/user/magic_link?token=#{token}"
    session = session |> visit(magic_link_url)

    # Preserve existing context data like groups
    {:ok,
     Map.merge(context, %{
       session: session,
       current_user: user
     })}
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
  defstep "I visit the groups page", %{session: session} = context do
    session = session |> visit("/groups")
    {:ok, Map.merge(context, %{session: session})}
  end

  defstep "I visit {string}", %{session: session, args: [path]} = context do
    # Wallaby handles redirects automatically
    session = session |> visit(path)
    {:ok, Map.merge(context, %{session: session})}
  end

  defstep "I visit the group page for {string}",
          %{session: session, args: [group_name]} = context do
    groups = Map.get(context, :groups, [])
    group = Enum.find(groups, fn g -> g.name |> to_string() == group_name end)

    # Wallaby handles redirects automatically
    session = session |> visit("/groups/#{group.id}")
    {:ok, Map.merge(context, %{session: session})}
  end

  # Form interaction steps
  defstep "I fill in the following:", context do
    # For 2-column tables without headers, Cucumber treats them as key-value pairs
    # Access the raw table data instead
    raw_table = context.datatable.raw

    # Fill in each field using Wallaby
    session =
      raw_table
      |> Enum.reduce(context.session, fn [field, value], acc_session ->
        # Use the field label directly with Wallaby
        fill_in(acc_session, text_field(field), with: value)
      end)

    # Store form data for later use
    form_params =
      raw_table
      |> Enum.reduce(%{}, fn [field, value], acc ->
        # Convert field names to snake_case for internal use
        field_name =
          case field do
            "Group Name" -> "name"
            "Description" -> "description"
            "Location" -> "location"
            _ -> String.downcase(String.replace(field, " ", "_"))
          end

        Map.put(acc, field_name, value)
      end)

    {:ok, Map.merge(context, %{session: session, form_data: form_params})}
  end

  defstep "I check {string}", %{session: session, args: [label]} = context do
    # Use Wallaby to check the checkbox
    session = session |> click(checkbox(label))

    # Update form data
    existing_form_data = Map.get(context, :form_data, %{})
    updated_form_data = Map.put(existing_form_data, "is_public", "true")

    {:ok, Map.merge(context, %{session: session, form_data: updated_form_data})}
  end

  defstep "I uncheck {string}", %{session: session, args: [label]} = context do
    # Use Wallaby to uncheck the checkbox - clicking an already checked checkbox unchecks it
    session = session |> click(checkbox(label))

    # Update form data
    existing_form_data = Map.get(context, :form_data, %{})
    updated_form_data = Map.put(existing_form_data, "is_public", "false")

    {:ok, Map.merge(context, %{session: session, form_data: updated_form_data})}
  end

  # Click actions
  defstep "I click {string}", %{session: session, args: [text]} = context do
    # Wallaby handles both links and buttons, and redirects automatically
    session =
      if has?(session, link(text)) do
        session |> click(link(text))
      else
        session |> click(button(text))
      end

    {:ok, Map.merge(context, %{session: session})}
  end

  defstep "I click on the group {string}", %{session: session, args: [group_name]} = context do
    # Click on the group link - Wallaby will handle the redirect
    session = session |> click(link(group_name))
    {:ok, Map.merge(context, %{session: session})}
  end

  # Assertions
  defstep "I should see {string}", %{session: session, args: [text]} = context do
    assert_has(session, css("body", text: text))
    {:ok, context}
  end

  defstep "I should not see {string}", %{session: session, args: [text]} = context do
    refute_has(session, css("body", text: text))
    {:ok, context}
  end

  defstep "I should be redirected to {string}", %{session: session, args: [path]} = context do
    # Wallaby provides current_path for checking current path
    assert session |> current_path() == path
    {:ok, context}
  end

  defstep "I should see an error on the {string} field",
          %{session: session, args: [field]} = context do
    # Look for error message in the HTML
    has_required = has?(session, css("body", text: "is required"))
    has_error = has?(session, css("body", text: "error"))

    assert has_required || has_error

    {:ok, context}
  end
end

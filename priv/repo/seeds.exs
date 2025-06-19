# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Huddlz.Repo.insert!(%Huddlz.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Huddlz.Accounts.User
alias Huddlz.Communities.{Group, GroupMember, Huddl}

# Check if data already exists
{:ok, existing_groups} = Ash.read(Group)

if Enum.empty?(existing_groups) do
  IO.puts("Creating sample data...")

  # Helper function to create a user with password and update role
  create_user = fn email, display_name, role ->
    # Use the create action which accepts all fields we need
    # First hash the password
    hashed_password = Bcrypt.hash_pwd_salt("Password123!")

    {:ok, user} =
      User
      |> Ash.Changeset.for_create(:create, %{
        email: email,
        display_name: display_name,
        role: role,
        confirmed_at: DateTime.utc_now(),
        hashed_password: hashed_password
      })
      |> Ash.create(authorize?: false)

    user
  end

  # Create admin user
  admin = create_user.("admin@example.com", "Admin User", :admin)
  IO.puts("Created admin user: #{admin.email}")

  # Create some verified users
  alice = create_user.("alice@example.com", "Alice Johnson", :verified)
  bob = create_user.("bob@example.com", "Bob Smith", :verified)
  carol = create_user.("carol@example.com", "Carol Davis", :verified)
  dave = create_user.("dave@example.com", "Dave Wilson", :regular)
  eve = create_user.("eve@example.com", "Eve Brown", :regular)

  users = [alice, bob, carol, dave, eve]
  IO.puts("Created #{length(users)} sample users")

  # Create some groups with meaningful names
  # Using Ash changesets directly to ensure slug generation works properly
  groups =
    [
      Group
      |> Ash.Changeset.for_create(
        :create_group,
        %{
          name: "Phoenix Elixir Meetup",
          description:
            "A group for Elixir enthusiasts in the Phoenix area. We meet monthly to discuss Elixir, Phoenix, LiveView, and more!",
          location: "Phoenix, AZ",
          is_public: true,
          owner_id: alice.id
        },
        actor: alice
      )
      |> Ash.create(),
      Group
      |> Ash.Changeset.for_create(
        :create_group,
        %{
          name: "Book Club Central",
          description:
            "Join us for our weekly book discussions. We read everything from fiction to technical books.",
          location: "Online",
          is_public: true,
          owner_id: bob.id
        },
        actor: bob
      )
      |> Ash.create(),
      Group
      |> Ash.Changeset.for_create(
        :create_group,
        %{
          name: "Hiking Adventures",
          description:
            "Weekend hiking trips for all skill levels. Safety first, adventure always!",
          location: "Various Trails",
          is_public: true,
          owner_id: carol.id
        },
        actor: carol
      )
      |> Ash.create(),
      Group
      |> Ash.Changeset.for_create(
        :create_group,
        %{
          name: "Private Tech Talks",
          description: "Exclusive tech talks for members only.",
          location: "Tech Hub",
          is_public: false,
          owner_id: admin.id
        },
        actor: admin
      )
      |> Ash.create()
    ]
    |> Enum.map(fn {:ok, group} -> group end)

  IO.puts("Created #{length(groups)} groups")

  # Add some members to groups
  # Add users to Phoenix Elixir Meetup
  phoenix_group = Enum.at(groups, 0)

  {:ok, _} =
    GroupMember
    |> Ash.Changeset.for_create(
      :add_member,
      %{
        group_id: phoenix_group.id,
        user_id: bob.id,
        role: :organizer
      },
      actor: alice
    )
    |> Ash.create()

  {:ok, _} =
    GroupMember
    |> Ash.Changeset.for_create(
      :add_member,
      %{
        group_id: phoenix_group.id,
        user_id: carol.id,
        role: :member
      },
      actor: alice
    )
    |> Ash.create()

  {:ok, _} =
    GroupMember
    |> Ash.Changeset.for_create(
      :add_member,
      %{
        group_id: phoenix_group.id,
        user_id: dave.id,
        role: :member
      },
      actor: alice
    )
    |> Ash.create()

  # Add users to Book Club
  book_group = Enum.at(groups, 1)

  {:ok, _} =
    GroupMember
    |> Ash.Changeset.for_create(
      :add_member,
      %{
        group_id: book_group.id,
        user_id: alice.id,
        role: :member
      },
      actor: bob
    )
    |> Ash.create()

  {:ok, _} =
    GroupMember
    |> Ash.Changeset.for_create(
      :add_member,
      %{
        group_id: book_group.id,
        user_id: eve.id,
        role: :member
      },
      actor: bob
    )
    |> Ash.create()

  IO.puts("Added members to groups")

  # Create some huddlz with meaningful titles
  hiking_group = Enum.at(groups, 2)

  huddlz =
    [
      # Phoenix Elixir Meetup huddlz
      Huddl
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Introduction to LiveView Components",
          description:
            "Learn how to build reusable LiveView components. We'll cover function components, live components, and when to use each.",
          event_type: :hybrid,
          starts_at: DateTime.add(DateTime.utc_now(), 7, :day) |> DateTime.truncate(:second),
          ends_at:
            DateTime.add(DateTime.utc_now(), 7 * 24 * 3600 + 2 * 3600, :second)
            |> DateTime.truncate(:second),
          physical_location: "TechHub Phoenix, 123 Main St",
          virtual_link: "https://zoom.us/j/123456789",
          group_id: phoenix_group.id,
          creator_id: alice.id
        },
        actor: alice
      )
      |> Ash.create(),
      Huddl
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Debugging Elixir Applications",
          description:
            "Deep dive into debugging techniques for Elixir apps. Bring your toughest bugs!",
          event_type: :virtual,
          starts_at: DateTime.add(DateTime.utc_now(), 14, :day) |> DateTime.truncate(:second),
          ends_at:
            DateTime.add(DateTime.utc_now(), 14 * 24 * 3600 + 3600, :second)
            |> DateTime.truncate(:second),
          virtual_link: "https://meet.google.com/abc-defg-hij",
          group_id: phoenix_group.id,
          creator_id: bob.id
        },
        actor: bob
      )
      |> Ash.create(),

      # Book Club huddlz
      Huddl
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Discussing 'The Phoenix Project'",
          description:
            "This month we're reading 'The Phoenix Project'. Join us to discuss DevOps culture and lessons learned.",
          event_type: :in_person,
          starts_at: DateTime.add(DateTime.utc_now(), 5, :day) |> DateTime.truncate(:second),
          ends_at:
            DateTime.add(DateTime.utc_now(), 5 * 24 * 3600 + 2 * 3600, :second)
            |> DateTime.truncate(:second),
          physical_location: "Central Library, Meeting Room A",
          group_id: book_group.id,
          creator_id: bob.id
        },
        actor: bob
      )
      |> Ash.create(),

      # Hiking Adventures huddlz
      Huddl
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Sunrise Hike at Camelback Mountain",
          description:
            "Early morning hike to catch the sunrise. Moderate difficulty, bring water and snacks!",
          event_type: :in_person,
          starts_at: DateTime.add(DateTime.utc_now(), 3, :day) |> DateTime.truncate(:second),
          ends_at:
            DateTime.add(DateTime.utc_now(), 3 * 24 * 3600 + 4 * 3600, :second)
            |> DateTime.truncate(:second),
          physical_location: "Camelback Mountain Trailhead",
          group_id: hiking_group.id,
          creator_id: carol.id
        },
        actor: carol
      )
      |> Ash.create()
    ]
    |> Enum.map(fn {:ok, huddl} -> huddl end)

  IO.puts("Created #{length(huddlz)} huddlz")
  IO.puts("\nSeed data created successfully!")
  IO.puts("\nYou can log in with:")
  IO.puts("  Admin: admin@example.com (password: Password123!)")

  IO.puts(
    "  Users: alice@example.com, bob@example.com, carol@example.com (password: Password123!)"
  )

  IO.puts("\nGroup slugs:")
  Enum.each(groups, fn g -> IO.puts("  /groups/#{g.slug} - #{g.name}") end)
else
  IO.puts("Data already exists, skipping seed data creation")
end

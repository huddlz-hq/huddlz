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

  # Create some users with location preferences
  alice = create_user.("alice@example.com", "Alice Johnson", :user)
  bob = create_user.("bob@example.com", "Bob Smith", :user)
  carol = create_user.("carol@example.com", "Carol Davis", :user)
  dave = create_user.("dave@example.com", "Dave Wilson", :user)
  eve = create_user.("eve@example.com", "Eve Brown", :user)

  # Set location preferences for some users
  {:ok, alice} =
    alice
    |> Ash.Changeset.for_update(:update_location_preferences, %{
      default_location_address: "San Francisco, CA",
      default_search_radius: 25
    })
    |> Ash.update(authorize?: false)

  {:ok, bob} =
    bob
    |> Ash.Changeset.for_update(:update_location_preferences, %{
      default_location_address: "New York, NY",
      default_search_radius: 50
    })
    |> Ash.update(authorize?: false)

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
          name: "San Francisco Elixir Meetup",
          description:
            "A group for Elixir enthusiasts in the San Francisco Bay Area. We meet monthly to discuss Elixir, Phoenix, LiveView, and more!",
          location: "San Francisco, CA",
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
          location: "New York, NY",
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
          location: "Los Angeles, CA",
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
          location: "Austin, TX",
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
  # Add users to San Francisco Elixir Meetup
  sf_group = Enum.at(groups, 0)

  {:ok, _} =
    GroupMember
    |> Ash.Changeset.for_create(
      :add_member,
      %{
        group_id: sf_group.id,
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
        group_id: sf_group.id,
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
        group_id: sf_group.id,
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
  private_group = Enum.at(groups, 3)

  # Generate more huddlz to test pagination
  # Create a mix of upcoming, past, and in-progress events
  huddlz = []

  # San Francisco Elixir Meetup huddlz (many events)
  sf_huddlz =
    Enum.map(1..15, fn i ->
      days_offset = i * 3
      event_type = Enum.random([:in_person, :virtual, :hybrid])

      # Set location fields based on event type
      # Use locations that are in our mock geocoding service
      {physical_location, virtual_link} =
        case event_type do
          :in_person ->
            # Rotate between different SF locations
            location =
              Enum.random([
                "San Francisco, CA",
                "123 Market Street, San Francisco, CA",
                "Golden Gate Park, San Francisco, CA"
              ])

            {location, nil}

          :virtual ->
            {nil, "https://zoom.us/j/#{:rand.uniform(999_999_999)}"}

          :hybrid ->
            {"San Francisco, CA", "https://zoom.us/j/#{:rand.uniform(999_999_999)}"}
        end

      {:ok, huddl} =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "SF Elixir Meetup ##{i}",
            description:
              "Join us for our regular meetup discussing Elixir, Phoenix, and LiveView topics.",
            event_type: event_type,
            starts_at:
              DateTime.add(DateTime.utc_now(), days_offset, :day) |> DateTime.truncate(:second),
            ends_at:
              DateTime.add(DateTime.utc_now(), days_offset * 24 * 3600 + 2 * 3600, :second)
              |> DateTime.truncate(:second),
            physical_location: physical_location,
            virtual_link: virtual_link,
            group_id: sf_group.id,
            creator_id: Enum.random([alice.id, bob.id])
          },
          actor: alice
        )
        |> Ash.create()

      huddl
    end)

  # Book Club past events (to test past events pagination)
  books = [
    "1984",
    "Dune",
    "The Hobbit",
    "Clean Code",
    "Design Patterns",
    "The Pragmatic Programmer",
    "Elixir in Action",
    "Programming Phoenix",
    "Domain Driven Design",
    "The Phoenix Project",
    "Sapiens",
    "Atomic Habits"
  ]

  book_past_huddlz =
    Enum.map(1..12, fn i ->
      days_ago = i * 7
      book_title = Enum.at(books, i - 1) || "Mystery Book #{i}"

      {:ok, huddl} =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Book Club: #{book_title}",
            description: "Our weekly book discussion. Bring your thoughts and favorite quotes!",
            event_type: :in_person,
            starts_at:
              DateTime.add(DateTime.utc_now(), -days_ago, :day) |> DateTime.truncate(:second),
            ends_at:
              DateTime.add(DateTime.utc_now(), -days_ago * 24 * 3600 + 2 * 3600, :second)
              |> DateTime.truncate(:second),
            physical_location: "New York, NY",
            group_id: book_group.id,
            creator_id: bob.id
          },
          actor: bob
        )
        |> Ash.create()

      huddl
    end)

  # Hiking Adventures mixed events
  trails = [
    "Griffith Observatory Trail",
    "Runyon Canyon",
    "Hollywood Sign Trail",
    "Temescal Canyon",
    "Solstice Canyon",
    "Will Rogers State Park",
    "Franklin Canyon",
    "Malibu Creek Trail"
  ]

  hiking_huddlz =
    Enum.map(1..8, fn i ->
      # Mix of past and future events
      days_offset = if i <= 4, do: i * 4, else: -(i - 4) * 5
      trail_name = Enum.at(trails, i - 1) || "Mystery Trail #{i}"

      difficulty =
        Enum.at(["beginner-friendly", "moderate", "challenging", "moderate"], rem(i - 1, 4))

      {:ok, huddl} =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Hike: #{trail_name}",
            description:
              "Join us for a #{difficulty} hike. Don't forget water and sun protection!",
            event_type: :in_person,
            starts_at:
              DateTime.add(DateTime.utc_now(), days_offset, :day) |> DateTime.truncate(:second),
            ends_at:
              DateTime.add(DateTime.utc_now(), days_offset * 24 * 3600 + 4 * 3600, :second)
              |> DateTime.truncate(:second),
            physical_location: "Los Angeles, CA",
            group_id: hiking_group.id,
            creator_id: carol.id
          },
          actor: carol
        )
        |> Ash.create()

      huddl
    end)

  # Add some in-progress events (starting within the last 2 hours)
  live_topics = ["Elixir Workshop", "Phoenix LiveView Demo", "OTP Basics"]

  in_progress_huddlz =
    Enum.map(1..3, fn i ->
      minutes_ago = i * 30
      topic = Enum.at(live_topics, i - 1)

      {:ok, huddl} =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "LIVE NOW: #{topic}",
            description: "This event is currently in progress! Join us now.",
            event_type: :virtual,
            starts_at:
              DateTime.add(DateTime.utc_now(), -minutes_ago, :minute)
              |> DateTime.truncate(:second),
            ends_at:
              DateTime.add(DateTime.utc_now(), 120 - minutes_ago, :minute)
              |> DateTime.truncate(:second),
            virtual_link: "https://zoom.us/j/live#{i}",
            group_id: sf_group.id,
            creator_id: alice.id
          },
          actor: alice
        )
        |> Ash.create()

      huddl
    end)

  # Some private group events (won't show in public search)
  tech_topics = [
    "AI/ML",
    "Blockchain",
    "Quantum Computing",
    "Cybersecurity",
    "Cloud Architecture"
  ]

  private_huddlz =
    Enum.map(1..5, fn i ->
      topic = Enum.at(tech_topics, i - 1)

      {:ok, huddl} =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Private Tech Talk: #{topic}",
            description: "Exclusive tech talk for members only.",
            event_type: :hybrid,
            starts_at:
              DateTime.add(DateTime.utc_now(), i * 5, :day) |> DateTime.truncate(:second),
            ends_at:
              DateTime.add(DateTime.utc_now(), i * 5 * 24 * 3600 + 3600, :second)
              |> DateTime.truncate(:second),
            physical_location: "Austin, TX",
            virtual_link: "https://privatemeeting.example.com/#{i}",
            group_id: private_group.id,
            creator_id: admin.id,
            is_private: true
          },
          actor: admin
        )
        |> Ash.create()

      huddl
    end)

  huddlz =
    sf_huddlz ++ book_past_huddlz ++ hiking_huddlz ++ in_progress_huddlz ++ private_huddlz

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

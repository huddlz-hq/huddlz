defmodule Huddlz.Generator do
  @moduledoc """
  Generators for creating test data.
  """
  use Ash.Generator

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl

  @doc """
  Create a user with given attributes.
  By default, users are confirmed. Pass confirmed_at: nil for unconfirmed users.
  """
  def user(opts \\ []) do
    # Default role to :user if not specified
    default_opts = [role: :user]
    merged_opts = Keyword.merge(default_opts, opts)

    seed_generator(
      %User{
        email: StreamData.repeatedly(fn -> Faker.Internet.email() end),
        display_name: StreamData.repeatedly(fn -> Faker.Person.name() end),
        # By default, test users are confirmed
        confirmed_at: DateTime.utc_now()
      },
      overrides: merged_opts
    )
  end

  @doc """
  Create a user with password authentication.
  """
  def user_with_password(opts \\ []) do
    password = opts[:password] || "Password123!"

    changeset_generator(
      User,
      :register_with_password,
      defaults: [
        email: StreamData.repeatedly(fn -> Faker.Internet.email() end),
        password: password,
        password_confirmation: password
      ],
      overrides: Keyword.drop(opts, [:password])
    )
  end

  @doc """
  Create a group membership with given attributes.
  """
  def group_member(opts \\ []) do
    actor =
      opts[:actor] ||
        once(:default_actor, fn ->
          generate(user(role: opts[:actor_role] || :admin))
        end)

    group_id =
      opts[:group_id] ||
        once(:default_group_id, fn ->
          generate(group()).id
        end)

    user_id =
      opts[:user_id] ||
        once(:default_user_id, fn ->
          generate(user(role: :regular)).id
        end)

    changeset_generator(
      GroupMember,
      :add_member,
      defaults: [
        role: "member",
        group_id: group_id,
        user_id: user_id
      ],
      overrides: opts,
      actor: actor
    )
  end

  @doc """
  Create a group with given attributes.
  """
  def group(opts \\ []) do
    actor =
      opts[:actor] ||
        once(:default_actor, fn ->
          generate(user(role: opts[:actor_role] || :user))
        end)

    owner_id =
      opts[:owner_id] ||
        once(:default_owner_id, fn ->
          generate(user()).id
        end)

    changeset_generator(
      Group,
      :create_group,
      defaults: [
        name: StreamData.repeatedly(fn -> Faker.Company.name() end),
        description: StreamData.repeatedly(fn -> Faker.Lorem.paragraph(2..3) end),
        location: "Test Location",
        is_public: true,
        owner_id: owner_id
      ],
      overrides: opts,
      actor: actor
    )
  end

  @doc """
  Create a past huddl using seed_generator (bypasses validations).
  Use this for creating test data with past dates.
  """
  def past_huddl(opts \\ []) do
    # Default group_id and creator_id if not provided
    group_id =
      opts[:group_id] ||
        once(:default_group_id, fn ->
          generate(group()).id
        end)

    creator_id =
      opts[:creator_id] ||
        once(:default_creator_id, fn ->
          generate(user(role: :user)).id
        end)

    # Default to 2 days ago
    default_starts_at = DateTime.add(DateTime.utc_now(), -2, :day)
    default_ends_at = DateTime.add(default_starts_at, 2, :hour)

    seed_generator(
      %Huddl{
        title: StreamData.repeatedly(fn -> Faker.Company.bs() end),
        description: StreamData.repeatedly(fn -> Faker.Lorem.paragraph(2..3) end),
        starts_at: default_starts_at,
        ends_at: default_ends_at,
        event_type: :in_person,
        physical_location: StreamData.repeatedly(fn -> Faker.Address.street_address() end),
        virtual_link: nil,
        is_private: false,
        rsvp_count: 0,
        thumbnail_url:
          StreamData.repeatedly(fn ->
            "https://placehold.co/600x400/#{random_hex_color()}/FFFFFF?text=Past+Huddl"
          end),
        group_id: group_id,
        creator_id: creator_id
      },
      overrides: opts
    )
  end

  @doc """
  Create a huddl with random data.
  """
  def huddl(opts \\ []) do
    actor =
      opts[:actor] ||
        once(:default_actor, fn ->
          generate(user(role: opts[:actor_role] || :user))
        end)

    creator_id =
      opts[:creator_id] ||
        once(:default_creator_id, fn ->
          generate(user(role: :user)).id
        end)

    group_id =
      opts[:group_id] ||
        once(:default_group_id, fn ->
          owner = generate(user(role: :user))
          generate(group(owner_id: owner.id, is_public: true, actor: owner)).id
        end)

    # Generate random dates in the future
    days_ahead = :rand.uniform(30)
    hours_duration = :rand.uniform(4)
    start_time = DateTime.add(DateTime.utc_now(), days_ahead, :day)
    end_time = DateTime.add(start_time, hours_duration, :hour)

    # Generate a thumbnail URL
    thumbnail_url =
      "https://placehold.co/600x400/#{random_hex_color()}/FFFFFF?text=Huddl"

    changeset_generator(
      Huddl,
      :create,
      defaults: [
        title: StreamData.repeatedly(fn -> Faker.Company.bs() end),
        description: StreamData.repeatedly(fn -> Faker.Lorem.paragraph(2..3) end),
        starts_at: start_time,
        ends_at: end_time,
        thumbnail_url: thumbnail_url,
        creator_id: creator_id,
        group_id: group_id,
        event_type: :in_person,
        physical_location: "123 Main St, Anytown, USA",
        is_private: false,
        rsvp_count: 0,
        huddl_template_id: nil,
        is_recurring: false
      ],
      overrides: opts,
      actor: actor
    )
  end

  @doc """
  Generate a host and multiple huddlz.
  """
  def host_with_huddlz(email \\ nil, count \\ 3, huddl_opts \\ []) do
    email = email || Faker.Internet.email()

    host =
      user(email: email, role: :user)
      |> generate()

    # Create a public group for the host
    public_group = generate(group(owner_id: host.id, is_public: true, actor: host))

    huddlz =
      huddl(
        Keyword.merge(
          [
            creator_id: host.id,
            group_id: public_group.id,
            is_private: false,
            actor: host
          ],
          huddl_opts
        )
      )
      |> generate_many(count)

    {host, huddlz}
  end

  # Helper function to generate random hex color
  defp random_hex_color do
    ["3D8BFD", "6610F2", "6F42C1", "D63384", "DC3545", "FD7E14", "FFC107", "198754"]
    |> Enum.random()
  end
end

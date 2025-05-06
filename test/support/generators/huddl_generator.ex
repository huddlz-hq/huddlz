defmodule Huddlz.Generators.HuddlGenerator do
  @moduledoc """
  Generators for creating Huddl test data.
  """
  use Ash.Generator

  alias Huddlz.Huddls.Huddl
  alias Huddlz.Generators.UserGenerator

  @doc """
  Create a huddl with random data.
  """
  def huddl(opts \\ []) do
    host = Keyword.get(opts, :host)
    host_id = if host, do: host.id, else: nil

    # Default values
    defaults = %{
      title: sequence(:title, &"Huddl #{&1}"),
      description: "Join us for an engaging discussion on interesting topics!",
      starts_at: DateTime.add(DateTime.utc_now(), Enum.random(1..30), :day),
      status: "upcoming",
      host_id: host_id
    }

    # Create seed generator with defaults that can be overridden
    seed_generator(
      Map.merge(defaults, Map.new(opts)),
      resource: Huddl
    )
  end

  @doc """
  Generate a host and multiple huddls.
  """
  def host_with_huddls(email, count \\ 3, huddl_opts \\ []) do
    host =
      UserGenerator.user(email: email)
      |> generate()

    Enum.map(1..count, fn _ ->
      huddl(Keyword.merge([host: host], huddl_opts))
      |> generate()
    end)

    host
  end

  @doc """
  Generate sample data for development or testing.
  """
  def sample_data do
    # Create hosts
    host1 = generate(UserGenerator.user(email: "host1@example.com"))
    host2 = generate(UserGenerator.user(email: "host2@example.com"))

    # Create huddls for each host
    [
      %{
        title: "Introduction to Elixir",
        description:
          "Learn the basics of functional programming with Elixir. Perfect for beginners!",
        starts_at: DateTime.add(DateTime.utc_now(), 2, :day),
        ends_at: DateTime.add(DateTime.utc_now(), 2, :day) |> DateTime.add(2, :hour),
        thumbnail_url: "https://placehold.co/600x400/444/FFF?text=Elixir",
        host_id: host1.id
      },
      %{
        title: "Phoenix LiveView Deep Dive",
        description: "Advanced session on building real-time features with Phoenix LiveView",
        starts_at: DateTime.add(DateTime.utc_now(), 5, :day),
        ends_at: DateTime.add(DateTime.utc_now(), 5, :day) |> DateTime.add(3, :hour),
        thumbnail_url: "https://placehold.co/600x400/3D8BFD/FFF?text=Phoenix",
        host_id: host1.id
      },
      %{
        title: "Functional Programming Principles",
        description: "Explore immutability, higher-order functions, and other FP concepts",
        starts_at: DateTime.add(DateTime.utc_now(), 7, :day),
        ends_at: DateTime.add(DateTime.utc_now(), 7, :day) |> DateTime.add(2, :hour),
        thumbnail_url: "https://placehold.co/600x400/5b9aa0/FFF?text=FP",
        host_id: host2.id
      },
      %{
        title: "Building APIs with Elixir",
        description: "Learn how to create robust and high-performance APIs",
        starts_at: DateTime.add(DateTime.utc_now(), 10, :day),
        ends_at: DateTime.add(DateTime.utc_now(), 10, :day) |> DateTime.add(4, :hour),
        thumbnail_url: "https://placehold.co/600x400/C68BFA/FFF?text=API",
        host_id: host2.id
      },
      %{
        title: "Database Design Best Practices",
        description: "Learn how to design efficient and scalable database schemas",
        starts_at: DateTime.add(DateTime.utc_now(), 14, :day),
        ends_at: DateTime.add(DateTime.utc_now(), 14, :day) |> DateTime.add(3, :hour),
        thumbnail_url: "https://placehold.co/600x400/6c757d/FFF?text=DB",
        host_id: host1.id
      }
    ]
    |> Enum.each(fn attrs ->
      generate(huddl(attrs))
    end)
  end
end
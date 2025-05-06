defmodule Huddlz.Generators.SoireeGenerator do
  @moduledoc """
  Generators for creating Soirée test data.
  """
  use Ash.Generator

  alias Huddlz.Soirees.Soiree
  alias Huddlz.Generators.UserGenerator

  @doc """
  Create a soirée with random data.
  """
  def soiree(opts \\ []) do
    host = Keyword.get(opts, :host)
    host_id = if host, do: host.id, else: nil

    # Default values
    defaults = %{
      title: sequence(:title, &"Soirée #{&1}"),
      description: "Join us for an engaging discussion on interesting topics!",
      starts_at: DateTime.add(DateTime.utc_now(), Enum.random(1..30), :day),
      status: "upcoming",
      host_id: host_id
    }

    # Create seed generator with defaults that can be overridden
    seed_generator(
      Map.merge(defaults, Map.new(opts)),
      resource: Soiree
    )
  end

  @doc """
  Generate a host and multiple soirées.
  """
  def host_with_soirees(email, count \\ 3, soiree_opts \\ []) do
    host =
      UserGenerator.user(email: email)
      |> generate()

    Enum.map(1..count, fn _ ->
      soiree(Keyword.merge([host: host], soiree_opts))
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

    # Create soirées for each host
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
      generate(soiree(attrs))
    end)
  end
end

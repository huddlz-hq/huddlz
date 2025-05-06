defmodule Huddlz.Soirees.Generators.SoireeGenerator do
  @moduledoc """
  Generators for creating Soirée test data.
  """
  use Ash.Generator

  alias Huddlz.Soirees.Soiree
  alias Huddlz.Accounts.Generators.UserGenerator

  @doc """
  Create a soirée with random data.
  """
  def soiree(opts \\ []) do
    host = Keyword.get(opts, :host)
    host_id = if host, do: host.id, else: nil

    # Generate random dates in the future
    days_ahead = :rand.uniform(30)
    hours_duration = :rand.uniform(4)
    start_time = DateTime.add(DateTime.utc_now(), days_ahead, :day)
    end_time = DateTime.add(start_time, hours_duration, :hour)

    # Random title using Faker with sequence for uniqueness
    title = Keyword.get(opts, :title, sequence(:title, &"#{Faker.Company.bs()} #{&1}"))
    
    # Generate a placeholder title for the URL that works with StreamData
    url_title = 
      case title do
        title when is_binary(title) -> String.replace(title, " ", "+")
        _ -> "Soiree" # Default placeholder if title is a StreamData object
      end

    # Generate a thumbnail URL
    thumbnail_url =
      "https://placehold.co/600x400/#{random_hex_color()}/FFFFFF?text=#{url_title}"

    # Create seed generator with default values
    seed_generator(
      %Soiree{
        title: title,
        description: Faker.Lorem.paragraph(2..3),
        starts_at: start_time,
        ends_at: end_time,
        status: "upcoming",
        thumbnail_url: thumbnail_url,
        host_id: host_id
      },
      overrides: opts
    )
  end

  @doc """
  Generate a host and multiple soirées.
  """
  def host_with_soirees(email \\ nil, count \\ 3, soiree_opts \\ []) do
    email = email || Faker.Internet.email()

    host =
      UserGenerator.user(email: email)
      |> generate()

    soirees =
      soiree(Keyword.merge([host: host], soiree_opts))
      |> generate_many(count)

    {host, soirees}
  end

  # Helper function to generate random hex color
  defp random_hex_color do
    ["3D8BFD", "6610F2", "6F42C1", "D63384", "DC3545", "FD7E14", "FFC107", "198754"]
    |> Enum.random()
  end
end

defmodule Huddlz.Accounts.DisplayNameGenerator do
  @moduledoc """
  Generates random display names for users.

  Creates names in the format: AdjectiveNounNumber (e.g., "HappyDolphin123")
  """

  @adjectives [
    "Happy",
    "Clever",
    "Gentle",
    "Brave",
    "Wise",
    "Cool",
    "Brilliant",
    "Swift",
    "Calm",
    "Daring"
  ]

  @nouns [
    "Dolphin",
    "Tiger",
    "Eagle",
    "Panda",
    "Wolf",
    "Falcon",
    "Bear",
    "Fox",
    "Lion",
    "Hawk"
  ]

  @doc """
  Generates a random display name in the format: AdjectiveNounNumber

  ## Examples

      iex> Huddlz.Accounts.DisplayNameGenerator.generate()
      "HappyDolphin123"
  """
  def generate do
    adjective = Enum.random(@adjectives)
    noun = Enum.random(@nouns)
    number = :rand.uniform(999)

    "#{adjective}#{noun}#{number}"
  end
end

defmodule Huddlz.Communities.SocialConnection.EncryptedString do
  @moduledoc """
  A string kept encrypted at rest through `Huddlz.Vault`. Loaded records
  carry the plain value; the column never does.
  """

  use Ash.Type

  @impl true
  def storage_type(_), do: :text

  # The API accepts a plain string as input and never returns the value.
  def graphql_type(_), do: :string
  def graphql_input_type(_), do: :string

  @impl true
  def cast_input(nil, _), do: {:ok, nil}
  def cast_input(value, _) when is_binary(value), do: {:ok, value}
  def cast_input(_, _), do: :error

  @impl true
  def cast_stored(nil, _), do: {:ok, nil}

  def cast_stored(value, _) when is_binary(value) do
    case Huddlz.Vault.decrypt(value) do
      {:ok, plain} -> {:ok, plain}
      :error -> :error
    end
  end

  def cast_stored(_, _), do: :error

  @impl true
  def dump_to_native(nil, _), do: {:ok, nil}
  def dump_to_native(value, _) when is_binary(value), do: {:ok, Huddlz.Vault.encrypt(value)}
  def dump_to_native(_, _), do: :error
end

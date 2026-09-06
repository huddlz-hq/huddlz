defmodule Huddlz.Communities.Huddl.Validations.WebUrlValidation do
  @moduledoc """
  Validates optional virtual links as absolute HTTP(S) URLs.
  """

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  @impl true
  def init(opts) do
    {:ok, Keyword.validate!(opts, [:attribute])}
  end

  @impl true
  def supports(_opts), do: [Ash.Changeset]

  @impl true
  def describe(_opts) do
    [
      message: "Must be a valid web address starting with http:// or https://",
      vars: []
    ]
  end

  @impl true
  def validate(changeset, opts, _context) do
    attribute = Keyword.fetch!(opts, :attribute)
    value = Ash.Changeset.get_attribute(changeset, attribute)

    if valid_web_url?(value) do
      :ok
    else
      {:error,
       InvalidAttribute.exception(
         field: attribute,
         value: value,
         message: "Must be a valid web address starting with http:// or https://"
       )}
    end
  end

  defp valid_web_url?(value) when value in [nil, ""], do: true

  defp valid_web_url?(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme, host: host}}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        true

      _ ->
        false
    end
  end

  defp valid_web_url?(_value), do: false
end

defmodule HuddlzWeb.MetaHelpers do
  @moduledoc """
  Helpers for building social sharing metadata.
  """

  @default_description_length 200

  def description(record, fallback, max_length \\ @default_description_length)

  def description(%{description: nil}, fallback, _max_length), do: fallback

  def description(%{description: description}, fallback, max_length) do
    description
    |> to_string()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> truncate(max_length)
    |> case do
      "" -> fallback
      text -> text
    end
  end

  def description(_record, fallback, _max_length), do: fallback

  def image_url(nil, _storage_module), do: nil

  def image_url(path, storage_module) do
    path
    |> storage_module.url()
    |> absolute_url()
  end

  defp absolute_url("http" <> _ = url), do: url
  defp absolute_url(path), do: HuddlzWeb.Endpoint.url() <> path

  defp truncate(text, max_length) do
    if String.length(text) <= max_length do
      text
    else
      text
      |> String.slice(0, max_length)
      |> String.replace(~r/\s+\S*$/, "")
      |> case do
        "" -> String.slice(text, 0, max_length)
        truncated -> truncated
      end
      |> Kernel.<>("...")
    end
  end
end

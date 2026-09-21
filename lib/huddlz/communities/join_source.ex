defmodule Huddlz.Communities.JoinSource do
  @moduledoc """
  The page or email a person joined a group from. Each join surface names
  itself; links from emails and notifications carry the name as a plain
  `from` tag. It says nothing about the person. A join that names no source
  has none.
  """

  use Ash.Type.Enum,
    values: [
      :huddl_page,
      :groups_page,
      :group_page,
      :join_suggestion_email,
      :join_suggestion_notification,
      :rsvp_confirmation_email
    ]

  @param "from"

  def graphql_type(_), do: :join_source

  @doc "The query parameter a link carries its source in."
  def param, do: @param

  @doc """
  The source a `from` tag names, or nil for a missing or unrecognised tag.
  """
  @spec from_tag(term()) :: atom() | nil
  def from_tag(tag) when is_binary(tag) do
    Enum.find(values(), &(Atom.to_string(&1) == tag))
  end

  def from_tag(_tag), do: nil

  @doc """
  The path with the source's tag added, for links that lead to a group page.
  """
  @spec tag(String.t(), atom()) :: String.t()
  def tag(path, source) when is_binary(path) and is_atom(source) do
    path <> "?" <> URI.encode_query(%{@param => source})
  end
end

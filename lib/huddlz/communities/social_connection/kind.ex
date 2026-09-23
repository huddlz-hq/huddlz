defmodule Huddlz.Communities.SocialConnection.Kind do
  @moduledoc "The platform a social connection posts to."

  use Ash.Type.Enum, values: [:slack, :discord]

  def graphql_type(_), do: :social_connection_kind

  @doc "The platform's name as people know it."
  def label(:slack), do: "Slack"
  def label(:discord), do: "Discord"
end

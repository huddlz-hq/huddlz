defmodule Huddlz.Social.Webhook do
  @moduledoc "Validates the platform-owned destination before storing or sending to it."

  @spec valid?(atom(), term()) :: boolean()
  def valid?(:slack, url) when is_binary(url) do
    Regex.match?(
      ~r/\Ahttps:\/\/hooks\.slack\.com\/services\/[A-Za-z0-9_-]+\/[A-Za-z0-9_-]+\/[A-Za-z0-9_-]+\z/,
      url
    )
  end

  def valid?(:discord, url) when is_binary(url) do
    Regex.match?(~r/\Ahttps:\/\/discord\.com\/api\/webhooks\/[0-9]+\/[A-Za-z0-9_-]+\z/, url)
  end

  def valid?(_kind, _url), do: false
end

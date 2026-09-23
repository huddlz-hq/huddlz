defmodule Huddlz.Social do
  @moduledoc """
  The platforms a group can connect a place on, and the hand-off to each:
  where to send the owner to consent, and how to turn the code they come
  back with into a webhook. Each platform is a `Huddlz.Social.Provider`.
  """

  alias Huddlz.Communities.SocialConnection.{EncryptedString, Kind}
  alias Huddlz.Social.Webhook

  @type place :: %{
          required(:workspace_name) => String.t(),
          required(:channel_name) => String.t(),
          required(:webhook_url) => String.t(),
          optional(:discord_guild_id) => String.t(),
          optional(:discord_channel_id) => String.t()
        }

  @doc "The provider for a kind."
  @spec provider(Kind.t()) :: module()
  def provider(:slack), do: Huddlz.Social.Slack
  def provider(:discord), do: Huddlz.Social.Discord

  @doc "The kind a route names, or nil."
  @spec kind_from_param(String.t()) :: Kind.t() | nil
  def kind_from_param(param) when is_binary(param) do
    Enum.find(Kind.values(), &(Atom.to_string(&1) == param))
  end

  @doc "Where the platform's consent screen is, carrying our state."
  @spec authorize_url(Kind.t(), String.t(), String.t()) :: String.t()
  def authorize_url(kind, state, redirect_uri) do
    provider(kind).authorize_url(config(kind), state, redirect_uri)
  end

  @doc "The place a returned code stands for."
  @spec exchange(Kind.t(), String.t(), String.t()) :: {:ok, place()} | {:error, term()}
  def exchange(kind, code, redirect_uri) do
    provider(kind).exchange(config(kind), code, redirect_uri, req_options())
  end

  @doc """
  Send one message through a connection. `{:error, :revoked}` means the
  platform no longer accepts the webhook, so the connection needs
  reconnecting; any other error may pass.
  """
  @spec post(Huddlz.Communities.SocialConnection.t(), String.t()) ::
          :ok | {:error, :revoked | term()}
  def post(%{kind: kind, webhook_url: secret}, text) when is_binary(text) do
    url = EncryptedString.reveal(secret)

    if Webhook.valid?(kind, url) do
      provider(kind).post(url, text, req_options())
    else
      {:error, :invalid_destination}
    end
  end

  @doc "The words a test post carries."
  @spec test_post_text(String.t()) :: String.t()
  def test_post_text(group_name) do
    "This is a test from huddlz. Posts for #{group_name} will appear here. Nothing else is needed."
  end

  @doc "The platform's settings, from `config :huddlz, :social`."
  @spec config(Kind.t()) :: keyword()
  def config(kind) do
    Application.get_env(:huddlz, :social, []) |> Keyword.get(kind, [])
  end

  @doc """
  Whether this server has the platform's app registered, so a hand-off can
  start. Without it the tile says so and the hand-off route refuses.
  """
  @spec configured?(Kind.t()) :: boolean()
  def configured?(kind) do
    config = config(kind)
    present?(config[:client_id]) and present?(config[:client_secret])
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  # Tests route the platform calls through Req.Test.
  defp req_options do
    case Application.get_env(:huddlz, :social_req_plug) do
      nil -> []
      plug -> [plug: plug]
    end
  end
end

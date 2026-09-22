defmodule Huddlz.Social.Discord do
  @moduledoc """
  Discord through its `webhook.incoming` consent flow: Discord's own screen
  picks the server and channel and hands back a webhook for that channel.
  The answer names the server and the webhook, not the channel, so the
  webhook's name stands in for the channel.
  """

  @behaviour Huddlz.Social.Provider

  @authorize_url "https://discord.com/oauth2/authorize"
  @token_url "https://discord.com/api/oauth2/token"

  @impl true
  def authorize_url(config, state, redirect_uri) do
    @authorize_url <>
      "?" <>
      URI.encode_query(%{
        client_id: config[:client_id] || "",
        scope: "webhook.incoming",
        response_type: "code",
        state: state,
        redirect_uri: redirect_uri
      })
  end

  @impl true
  def exchange(config, code, redirect_uri, req_options) do
    form = [
      client_id: config[:client_id] || "",
      client_secret: config[:client_secret] || "",
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri
    ]

    case Req.post(@token_url, [form: form, retry: false] ++ req_options) do
      {:ok, %{status: 200, body: body}} -> place(body)
      {:ok, %{status: status}} -> {:error, {:status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp place(%{"webhook" => %{"url" => url} = webhook} = body) when is_binary(url) do
    {:ok,
     %{
       workspace_name: get_in(body, ["guild", "name"]) || "Discord",
       channel_name: "#" <> (webhook["name"] || "channel"),
       webhook_url: url
     }}
  end

  defp place(_body), do: {:error, :no_webhook}

  @impl true
  def post(webhook_url, text, req_options) do
    case Req.post(webhook_url, [json: %{"content" => text}, retry: false] ++ req_options) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} when status in [403, 404, 410] -> {:error, :revoked}
      {:ok, %{status: status}} -> {:error, {:status, status}}
      {:error, reason} -> {:error, reason}
    end
  end
end

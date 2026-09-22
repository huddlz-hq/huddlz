defmodule Huddlz.Social.Slack do
  @moduledoc """
  Slack through "Add to Slack" with only the `incoming-webhook` scope:
  Slack's own screen picks the workspace and channel and hands back a
  webhook for that one channel.
  """

  @behaviour Huddlz.Social.Provider

  @authorize_url "https://slack.com/oauth/v2/authorize"
  @access_url "https://slack.com/api/oauth.v2.access"

  @impl true
  def authorize_url(config, state, redirect_uri) do
    @authorize_url <>
      "?" <>
      URI.encode_query(%{
        client_id: config[:client_id] || "",
        scope: "incoming-webhook",
        state: state,
        redirect_uri: redirect_uri
      })
  end

  @impl true
  def exchange(config, code, redirect_uri, req_options) do
    form = [
      client_id: config[:client_id] || "",
      client_secret: config[:client_secret] || "",
      code: code,
      redirect_uri: redirect_uri
    ]

    case Req.post(@access_url, [form: form, retry: false] ++ req_options) do
      {:ok, %{status: 200, body: %{"ok" => true} = body}} -> place(body)
      {:ok, %{status: 200, body: %{"error" => error}}} -> {:error, error}
      {:ok, %{status: status}} -> {:error, {:status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp place(%{"incoming_webhook" => %{"url" => url, "channel" => channel}} = body)
       when is_binary(url) and is_binary(channel) do
    {:ok,
     %{
       workspace_name: get_in(body, ["team", "name"]) || "Slack",
       channel_name: channel,
       webhook_url: url
     }}
  end

  defp place(_body), do: {:error, :no_webhook}

  @impl true
  def post(webhook_url, text, req_options) do
    case Req.post(webhook_url, [json: %{"text" => text}, retry: false] ++ req_options) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} when status in [403, 404, 410] -> {:error, :revoked}
      {:ok, %{status: status}} -> {:error, {:status, status}}
      {:error, reason} -> {:error, reason}
    end
  end
end

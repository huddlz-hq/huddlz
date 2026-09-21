defmodule HuddlzWeb.JoinSourceTag do
  @moduledoc """
  Takes the `from` tag off a group page address and remembers it for the
  visit.

  Links from emails and notifications name themselves in a `from` tag (see
  `Huddlz.Communities.JoinSource`). Left in the address, the tag would travel
  with a copied or bookmarked link and credit other people's joins to the
  email. So a recognised tag moves into the session, beside the group it was
  for and when it arrived, and the request is redirected to the clean
  address. An unrecognised tag is dropped.

  The session is what lets the source outlast tab changes, reconnects and
  reloads. It counts for page loads within 30 minutes of arriving; a page
  that stays open keeps the source it loaded with.
  """

  @behaviour Plug

  import Plug.Conn

  alias Huddlz.Communities.JoinSource
  alias Plug.Conn.Query

  @session_key "join_source"
  @visit_seconds 30 * 60

  @impl true
  def init(opts), do: opts

  @impl true
  def call(
        %Plug.Conn{method: "GET", path_info: ["groups", slug], query_params: %{"from" => tag}} =
          conn,
        _opts
      ) do
    conn
    |> remember(slug, JoinSource.from_tag(tag))
    |> Phoenix.Controller.redirect(to: clean_path(conn))
    |> halt()
  end

  def call(conn, _opts), do: conn

  @doc """
  The source remembered for this group in the session, or nil when there is
  none or the visit it belonged to is over.
  """
  @spec source_for(map(), String.t(), DateTime.t()) :: atom() | nil
  def source_for(session, slug, now \\ DateTime.utc_now()) do
    case session[@session_key] do
      %{"slug" => ^slug, "source" => tag, "at" => at} when is_integer(at) ->
        if DateTime.to_unix(now) - at <= @visit_seconds, do: JoinSource.from_tag(tag)

      _ ->
        nil
    end
  end

  defp remember(conn, slug, nil) do
    case get_session(conn, @session_key) do
      %{"slug" => ^slug} -> delete_session(conn, @session_key)
      _ -> conn
    end
  end

  defp remember(conn, slug, source) do
    put_session(conn, @session_key, %{
      "slug" => slug,
      "source" => Atom.to_string(source),
      "at" => DateTime.to_unix(DateTime.utc_now())
    })
  end

  defp clean_path(%Plug.Conn{request_path: path, query_params: query}) do
    case Map.delete(query, JoinSource.param()) do
      rest when map_size(rest) == 0 -> path
      rest -> path <> "?" <> Query.encode(rest)
    end
  end
end

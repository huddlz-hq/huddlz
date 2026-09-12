defmodule HuddlzWeb.MarkActive do
  @moduledoc """
  Records the signed-in person behind a request as active today. Sits
  after authentication in the browser and API pipelines; a request with
  nobody signed in passes through untouched.
  """

  @behaviour Plug

  alias Huddlz.Accounts.ActiveDays

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    ActiveDays.mark(conn.assigns[:current_user] || Ash.PlugHelpers.get_actor(conn))
    conn
  end
end

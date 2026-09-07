defmodule Huddlz.Sitemaps do
  @moduledoc """
  Generates durable, atomically published sitemap documents. HTTP reads never
  generate content. Refresh runs against one database snapshot in bounded batches.
  """
  import Ecto.Query
  use HuddlzWeb, :verified_routes
  alias Ecto.Adapters.SQL
  alias Huddlz.Repo
  alias Huddlz.Sitemaps.XML

  def fetch(name) do
    Repo.one(from d in "sitemap_documents", where: d.name == ^name, select: d.body)
  end

  def refresh(opts \\ []) do
    Repo.transaction(
      fn ->
        # A transaction-scoped lock prevents competing refreshes across machines.
        %{rows: [[locked?]]} = Repo.query!("SELECT pg_try_advisory_xact_lock(258, 1)")
        if locked?, do: generate(opts)
        :ok
      end,
      timeout: :timer.minutes(10)
    )
  end

  defp generate(opts) do
    now = DateTime.utc_now()
    # Retention begins when a document is superseded, even after a long outage.
    Repo.update_all(from(d in "sitemap_documents", where: d.active == true),
      set: [active: false, retained_at: now]
    )

    # One cursor statement has a consistent MVCC snapshot, including both kinds
    # of page. The unique kind/id ordering never relies on shifting offsets.
    sql = """
    SELECT 'group' AS kind, g.id::text AS id, g.slug, greatest(g.updated_at, g.sitemap_modified_at) AS modified_at
    FROM groups g WHERE g.is_public = true
    UNION ALL
    SELECT 'huddl', h.id::text, g.slug, greatest(h.sitemap_modified_at, g.updated_at, g.sitemap_modified_at)
    FROM huddlz h JOIN groups g ON g.id = h.group_id
    WHERE g.is_public = true AND h.is_private = false
      AND h.lifecycle_state IN ('published', 'completed')
    ORDER BY kind, id
    """

    files =
      Repo
      |> SQL.stream(sql, [], max_rows: 500)
      |> Stream.flat_map(& &1.rows)
      |> Stream.map(&entry/1)
      |> XML.urlsets(opts)
      |> Stream.map(fn body ->
        file = "#{digest(body)}.xml"
        store("sitemap-#{file}", body, now)
        url(~p"/sitemap-#{file}")
      end)

    index = XML.index(files)
    store("sitemap.xml", index, now)
    cutoff = DateTime.add(now, -48, :hour)

    Repo.delete_all(
      from d in "sitemap_documents", where: d.active == false and d.retained_at < ^cutoff
    )
  end

  defp entry([kind, id, slug, modified]) do
    loc =
      case kind do
        "group" -> url(~p"/groups/#{slug}")
        "huddl" -> url(~p"/groups/#{slug}/huddlz/#{id}")
      end

    {loc, DateTime.from_naive!(modified, "Etc/UTC")}
  end

  defp store(name, body, now) do
    Repo.insert_all(
      "sitemap_documents",
      [%{name: name, body: body, retained_at: now, active: true}],
      on_conflict: {:replace, [:body, :retained_at, :active]},
      conflict_target: [:name]
    )
  end

  def digest(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
end

defmodule Huddlz.RateLimit do
  @moduledoc """
  Distributed rate-limit store for the authentication actions.

  Each web node keeps its own local [Hammer](https://hexdocs.pm/hammer) ETS counter
  and broadcasts every increment to the other nodes over `Phoenix.PubSub`. A node
  counts its own hits directly and applies the other nodes' hits as it hears about
  them, so every node's window reflects the whole cluster's traffic.

  This is *eventually* consistent: during a burst a key can briefly exceed its limit
  by roughly the number of nodes, and a node that has just (re)started counts from
  zero until broadcasts catch up. That trade-off is fine for the coarse auth caps
  here and needs no extra infrastructure beyond the PubSub we already run.

  This module is the `AshRateLimiter.Backend` referenced by the `rate_limit` block on
  `Huddlz.Accounts.User`. Because enforcement lives on the Ash actions (not at the
  HTTP edge), this store can be swapped for a strongly-consistent shared one
  (Postgres/Redis) later without touching any per-action limit.
  """

  @behaviour AshRateLimiter.Backend

  @pubsub Huddlz.PubSub
  @topic "huddlz:rate_limit"

  defmodule Local do
    @moduledoc false
    use Hammer, backend: :ets
  end

  defmodule Listener do
    @moduledoc false
    use GenServer

    alias Huddlz.RateLimit

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    @impl GenServer
    def init(opts) do
      pubsub = Keyword.fetch!(opts, :pubsub)
      topic = Keyword.fetch!(opts, :topic)
      :ok = Phoenix.PubSub.subscribe(pubsub, topic)
      {:ok, %{}}
    end

    # Hits made on this node are already counted by `Local.hit/4`, and PubSub echoes
    # our own broadcast back to us, so we only apply increments from other nodes.
    @impl GenServer
    def handle_info({:inc, key, scale, increment, origin}, state) do
      unless origin == node(), do: RateLimit.Local.inc(key, scale, increment)
      {:noreply, state}
    end

    def handle_info(_message, state), do: {:noreply, state}
  end

  @doc false
  @impl AshRateLimiter.Backend
  def hit(key, scale, limit), do: hit(key, scale, limit, 1)

  @doc """
  Counts `increment` events against `key` within the `scale` (ms) window and reports
  whether `limit` has been exceeded across the cluster.

  Returns `{:allow, count}` when the event is allowed, or `{:deny, retry_after_ms}`
  when the limit has been reached.
  """
  def hit(key, scale, limit, increment) do
    if enabled?() do
      Phoenix.PubSub.broadcast(@pubsub, @topic, {:inc, key, scale, increment, node()})
      Local.hit(key, scale, limit, increment)
    else
      {:allow, 0}
    end
  end

  # Kill-switch. Defaults on; the test env disables it (`config :huddlz,
  # :rate_limit_enabled, false`) so the suite isn't throttled, and the rate-limit
  # tests flip it back on for their own scope.
  defp enabled?, do: Application.get_env(:huddlz, :rate_limit_enabled, true)

  @doc false
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :supervisor}
  end

  @doc false
  def start_link(opts) do
    children = [
      {Local, opts},
      {Listener, pubsub: @pubsub, topic: @topic}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end
end

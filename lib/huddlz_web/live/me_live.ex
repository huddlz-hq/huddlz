defmodule HuddlzWeb.MeLive do
  @moduledoc """
  Personal dashboard for authenticated members. Renders the huddlz the user
  is hosting and attending. Discovery (search, filters, all-upcoming) lives
  on `/discover`; this view focuses on the user's own activity.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias HuddlzWeb.Layouts

  @section_limit 6
  @huddl_card_loads [:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group]

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:section_limit, @section_limit)
     |> assign(:page_title, "Your dashboard")
     |> assign(:hosting, load_section(user, :hosting))
     |> assign(:attending, load_section(user, :attending))}
  end

  defp load_section(user, relationship) do
    page =
      Communities.search_huddlz(
        nil,
        :upcoming,
        nil,
        nil,
        nil,
        nil,
        relationship,
        actor: user,
        page: [limit: @section_limit, offset: 0, count: true]
      )

    case page do
      {:ok, %{results: results, count: count}} ->
        loaded = Ash.load!(results, @huddl_card_loads, actor: user)
        {loaded, count || length(loaded)}

      _ ->
        {[], 0}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-12">
        <header>
          <span class="mono-label text-primary/70">// Your dashboard</span>
          <h1 class="font-display text-3xl tracking-tight text-glow mt-2">
            {greeting(@current_user)}
          </h1>
          <p class="mt-2 text-base-content/60">
            The huddlz you're hosting and the ones you've RSVP'd to. Use search to find more.
          </p>
        </header>

        <.personal_section
          title="Hosting"
          section={@hosting}
          limit={@section_limit}
          view_all_path={~p"/?yours=hosting"}
          empty_message="You aren't hosting any upcoming huddlz."
        />

        <.personal_section
          title="Attending"
          section={@attending}
          limit={@section_limit}
          view_all_path={~p"/?yours=attending"}
          empty_message="You haven't RSVP'd to any upcoming huddlz."
        />
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :section, :any, required: true
  attr :limit, :integer, required: true
  attr :view_all_path, :string, required: true
  attr :empty_message, :string, required: true

  defp personal_section(assigns) do
    {huddls, count} = assigns.section
    assigns = assign(assigns, huddls: huddls, count: count)

    ~H"""
    <section>
      <div class="flex items-baseline justify-between gap-2">
        <h2 class="font-display text-lg tracking-tight text-glow flex items-baseline gap-3">
          <span class="mono-label text-primary/70">// {@title}</span>
          <span class="text-sm font-body font-normal text-base-content/40">
            ({@count})
          </span>
        </h2>
        <.link
          :if={@count > @limit}
          navigate={@view_all_path}
          class="text-xs text-primary hover:underline font-medium tracking-wide uppercase"
        >
          View all →
        </.link>
      </div>

      <%= if @count == 0 do %>
        <div class="border border-dashed border-base-300 p-8 mt-4 text-center text-base-content/50">
          {@empty_message}
        </div>
      <% else %>
        <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 mt-4">
          <%= for huddl <- @huddls do %>
            <.huddl_card huddl={huddl} show_group={true} />
          <% end %>
        </div>
      <% end %>
    </section>
    """
  end

  defp greeting(%{display_name: name}) when is_binary(name) and name != "" do
    case name |> String.trim() |> String.split(~r/\s+/, parts: 2) do
      [first | _] when first != "" -> "Welcome back, #{first}."
      _ -> "Welcome back."
    end
  end

  defp greeting(_), do: "Welcome back."
end

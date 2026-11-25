defmodule HuddlzWeb.OrganizeLive.Social do
  @moduledoc "The organizer workspace for a group's social connections and scheduled posts."
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Communities.SocialConnection
  alias Huddlz.Communities.SocialConnection.Kind
  alias Huddlz.Communities.SocialConnection.Moment
  alias Huddlz.Communities.SocialPost.Occasion
  alias Huddlz.Social
  alias Huddlz.Social.Post
  alias HuddlzWeb.FormFocus
  alias HuddlzWeb.OrganizeLive.Workspace

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}
  on_mount {HuddlzWeb.LiveUserAuth, :confirmed_user_required}

  @impl true
  def handle_params(%{"group_slug" => slug} = params, _uri, socket) do
    previous_group = socket.assigns[:group]

    case Workspace.open(socket, slug) do
      {:ok, socket} ->
        subscribe_to_group_changes(socket, previous_group)
        socket = socket |> assign_access() |> load_connections()
        connected_id = params["connected"]

        editor =
          if socket.assigns.access == :manage,
            do: Enum.find(socket.assigns.connections, &(&1.id == connected_id))

        {:noreply,
         socket
         |> assign(:connected_id, connected_id)
         |> reset_dialogs(editor)}

      {:error, socket} ->
        {:noreply, socket}
    end
  end

  defp subscribe_to_group_changes(socket, previous_group) do
    group = socket.assigns.group

    if connected?(socket) && (is_nil(previous_group) || previous_group.id != group.id) do
      if previous_group,
        do: Phoenix.PubSub.unsubscribe(Huddlz.PubSub, "group:#{previous_group.id}")

      Phoenix.PubSub.subscribe(Huddlz.PubSub, "group:#{group.id}")
    end
  end

  @impl true
  def handle_info({change, id}, %{assigns: %{group: %{id: id}}} = socket)
      when change in [:group_membership_changed, :group_changed] do
    case Workspace.refresh(socket) do
      {:ok, socket} ->
        socket = socket |> assign_access() |> load_connections()
        {:noreply, if(socket.assigns.access == :manage, do: socket, else: reset_dialogs(socket))}

      {:error, socket} ->
        {:noreply, socket}
    end
  end

  def handle_info({change, _id}, socket)
      when change in [:group_membership_changed, :group_changed],
      do: {:noreply, socket}

  defp assign_access(socket) do
    assign(socket, :access, access(socket.assigns.group, socket.assigns.current_user))
  end

  defp access(%{archived_at: at}, _user) when not is_nil(at), do: :read_only
  defp access(%{is_public: false}, _user), do: :read_only
  defp access(%{owner_id: id}, %{id: id}), do: :manage
  defp access(_group, _user), do: :pause_resume

  defp reset_dialogs(socket, editor \\ nil) do
    socket
    |> assign(connect_dialog?: false, removing_connection?: false)
    |> assign_schedule(editor)
  end

  defp load_connections(socket) do
    %{group: group, current_user: user} = socket.assigns

    socket
    |> assign(:connections, Communities.list_social_connections!(group.id, actor: user))
    |> assign(:upcoming_posts, Communities.list_upcoming_social_posts!(group.id, actor: user))
    |> assign(:recent_posts, Communities.list_recent_social_posts!(group.id, actor: user))
  end

  @impl true
  def handle_event(_event, _params, %{assigns: %{access: :read_only}} = socket),
    do: {:noreply, socket}

  def handle_event("pause_connection", %{"id" => id}, socket) do
    set_connection_state(socket, id, &Communities.pause_social_connection/2, "is paused.")
  end

  def handle_event("resume_connection", %{"id" => id}, socket) do
    set_connection_state(socket, id, &Communities.resume_social_connection/2, "is posting again.")
  end

  def handle_event(_event, _params, %{assigns: %{access: :pause_resume}} = socket),
    do: {:noreply, socket}

  def handle_event("open_connect_dialog", _params, socket) do
    {:noreply, assign(socket, :connect_dialog?, true)}
  end

  def handle_event("close_connect_dialog", _params, socket) do
    {:noreply, assign(socket, :connect_dialog?, false)}
  end

  def handle_event("edit_connection", %{"id" => id}, socket) do
    editor = Enum.find(socket.assigns.connections, &(&1.id == id))
    {:noreply, assign_schedule(socket, editor)}
  end

  def handle_event("close_schedule", _params, socket) do
    {:noreply, close_schedule(socket)}
  end

  # Dismiss queued form and dialog actions after the editor has closed.
  def handle_event(_event, _params, %{assigns: %{schedule_editor: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("ask_remove_connection", _params, socket) do
    {:noreply, assign(socket, :removing_connection?, true)}
  end

  def handle_event("cancel_remove_connection", _params, socket) do
    {:noreply, assign(socket, :removing_connection?, false)}
  end

  def handle_event(
        "remove_connection",
        _params,
        %{assigns: %{removing_connection?: false}} = socket
      ),
      do: {:noreply, socket}

  def handle_event("remove_connection", _params, socket) do
    %{schedule_editor: connection, current_user: user} = socket.assigns

    case Communities.remove_social_connection(connection, actor: user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "#{SocialConnection.place(connection)} is no longer connected.")
         |> close_schedule()
         |> load_connections()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "That connection didn't go.")}
    end
  end

  def handle_event("send_test_post", _params, socket) do
    %{schedule_editor: connection, current_user: user} = socket.assigns

    case Communities.send_social_test_post(connection.id, actor: user) do
      :ok ->
        {:noreply,
         put_flash(socket, :info, "A test post went to #{SocialConnection.place(connection)}.")}

      {:error, error} ->
        {:noreply,
         socket
         |> load_connections()
         |> put_flash(:error, test_post_error(error))}
    end
  end

  def handle_event("save_schedule", params, socket) do
    {:noreply, save_schedule(socket, params)}
  end

  def handle_event("finish_schedule", params, socket) do
    socket = save_schedule(socket, params)
    {:noreply, finish_schedule(socket, socket.assigns.schedule_form.source.valid?)}
  end

  defp save_schedule(socket, params) do
    attrs = Map.put(params["schedule"] || %{}, "moments", chosen_moments(params["moments"]))
    form = AshPhoenix.Form.validate(socket.assigns.schedule_form, attrs)

    socket
    |> assign(:moments_form, to_form(params["moments"] || %{}, as: :moments))
    |> persist_schedule(form)
  end

  defp persist_schedule(socket, %AshPhoenix.Form{valid?: true, changed?: false}), do: socket

  defp persist_schedule(socket, form) do
    case AshPhoenix.Form.submit(form, params: form.params) do
      {:ok, updated} ->
        socket
        |> assign_schedule(updated)
        |> load_connections()

      {:error, form} ->
        assign(socket, :schedule_form, to_form(form))
    end
  end

  defp finish_schedule(socket, false), do: FormFocus.first_error(socket, "schedule-form")

  defp finish_schedule(socket, true) do
    socket
    |> put_flash(
      :info,
      "#{SocialConnection.place(socket.assigns.schedule_editor)} will post on that schedule."
    )
    |> close_schedule()
  end

  defp assign_schedule(socket, nil) do
    assign(socket, schedule_editor: nil, schedule_form: nil, moments_form: nil)
  end

  defp assign_schedule(socket, connection) do
    form =
      connection
      |> AshPhoenix.Form.for_update(:edit, actor: socket.assigns.current_user, as: "schedule")
      |> to_form()

    moments = Map.new(Moment.values(), &{Atom.to_string(&1), &1 in connection.moments})

    assign(socket,
      schedule_editor: connection,
      schedule_form: form,
      moments_form: to_form(moments, as: :moments)
    )
  end

  defp close_schedule(socket) do
    socket = reset_dialogs(socket)

    case socket.assigns.connected_id do
      nil -> socket
      _id -> push_patch(socket, to: ~p"/organize/#{socket.assigns.group.slug}/social")
    end
  end

  defp set_connection_state(socket, id, change, said) do
    %{current_user: user} = socket.assigns
    connection = Enum.find(socket.assigns.connections, &(&1.id == id))

    case connection && change.(connection, actor: user) do
      {:ok, _connection} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{SocialConnection.place(connection)} #{said}")
         |> load_connections()}

      _ ->
        {:noreply, put_flash(socket, :error, "That didn't change.")}
    end
  end

  defp test_post_error(%Ash.Error.Invalid{errors: [%{message: message} | _]}), do: message
  defp test_post_error(_error), do: "The test post didn't go through."

  # The morning-of post for a made-up huddl this evening, worded by the same
  # formatter scheduled posts use, so the preview cannot drift from a post.
  defp preview_text(group, opening_line) do
    today = group.time_zone |> DateTime.now!() |> DateTime.to_date()

    Post.text(
      %{
        title: "Your next huddl with #{group.name}",
        starts_at: DateTime.new!(today, ~T[18:00:00], group.time_zone),
        time_zone: group.time_zone,
        event_type: :virtual,
        max_attendees: 20,
        rsvp_count: 8,
        waitlist_count: 0
      },
      moment: :morning_of,
      opening_line: opening_line,
      link: url(~p"/groups/#{group.slug}/huddlz/example")
    )
  end

  # Checkbox params: %{"week_before" => "true"} for the ticked moments.
  defp chosen_moments(nil), do: []

  defp chosen_moments(params) when is_map(params) do
    Enum.filter(Moment.values(), fn moment -> params[Atom.to_string(moment)] == "true" end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active_group_slug={@group.slug}
      active_organize_section={:social}
    >
      <Workspace.archived_banner group={@group} current_user={@current_user} />
      <div class="page-head">
        <div>
          <h1>Social</h1>
          <p>
            Post each huddl to the places your people already talk. Only public huddlz in public groups are posted.
          </p>
        </div>
        <.button
          :if={@access == :manage}
          id="connect-place"
          type="button"
          variant={:primary}
          phx-click="open_connect_dialog"
        >
          Connect a place
        </.button>
      </div>

      <section :if={!@group.is_public} id="social-private-note" class="panel">
        <p class="muted">
          Only public groups post to outside places: a link to a private group's huddl dead-ends for anyone who isn't a member.
        </p>
      </section>

      <section
        :if={@access == :pause_resume}
        id="social-organizer-note"
        class="panel"
      >
        <p class="muted">
          The group owner sets up social connections. You can pause one, skip a huddl, or post a huddl now.
        </p>
      </section>

      <section :if={@group.is_public} id="social-connections" class="panel">
        <div class="panel-head">
          <div>
            <h2>Social connections</h2>
            <div class="panel-sub">Each one posts on its own social schedule.</div>
          </div>
        </div>
        <p :if={@connections == []} class="muted">
          Nothing connected yet. Connect a Slack or Discord channel once and huddlz posts every public huddl there.
        </p>
        <div :if={@connections != []} class="row-list">
          <div
            :for={connection <- @connections}
            id={"social-connection-#{connection.id}"}
            class="row social-row"
          >
            <span class={["place-mark", Atom.to_string(connection.kind)]} aria-hidden="true">
              {String.first(Kind.label(connection.kind))}
            </span>
            <span class="row-title">
              {connection.channel_name}
              <span class="meta">
                {Kind.label(connection.kind)} · {connection.workspace_name}
                <span :if={connection.connected_by}>· connected by {connection.connected_by.display_name}</span>
              </span>
              <.link
                :if={SocialConnection.destination_url(connection)}
                href={SocialConnection.destination_url(connection)}
                target="_blank"
                rel="noopener noreferrer"
                class="meta underline"
              >Open channel</.link>
              <span :if={connection.opening_line} class="meta social-opening-line">
                Opens with “{connection.opening_line}”
              </span>
            </span>
            <span class="social-moments">
              <span :for={moment <- connection.moments} class="pill">{Moment.short(moment)}</span>
              <span :if={connection.moments == []} class="pill muted">No schedule yet</span>
            </span>
            <.pill variant={state_variant(connection.state)}>{state_label(connection.state)}</.pill>
            <span :if={@access != :read_only} class="social-actions">
              <.button
                :if={connection.state == :posting}
                id={"pause-connection-#{connection.id}"}
                type="button"
                variant={:secondary}
                phx-click="pause_connection"
                phx-value-id={connection.id}
              >
                Pause
              </.button>
              <.button
                :if={connection.state == :paused}
                id={"resume-connection-#{connection.id}"}
                type="button"
                variant={:secondary}
                phx-click="resume_connection"
                phx-value-id={connection.id}
              >
                Resume
              </.button>
              <.button
                :if={@access == :manage}
                id={"edit-connection-#{connection.id}"}
                type="button"
                variant={:secondary}
                phx-click="edit_connection"
                phx-value-id={connection.id}
              >
                Edit
              </.button>
            </span>
          </div>
        </div>
      </section>

      <section :if={@group.is_public && @connections != []} id="upcoming-social-posts" class="panel">
        <div class="panel-head">
          <div>
            <h2>Upcoming posts</h2>
            <div class="panel-sub">
              Times are in each huddl's time zone. A paused connection posts nothing, so its posts are not listed.
            </div>
          </div>
        </div>
        <p :if={@upcoming_posts == []} class="muted">
          Nothing to post yet. Posts appear here as public huddlz are published.
        </p>
        <div :if={@upcoming_posts != []} class="row-list">
          <div
            :for={post <- @upcoming_posts}
            id={"social-post-#{post.id}"}
            class="row social-post-row"
          >
            <span class="social-post-time">{post_time(post.due_at, post.huddl)}</span>
            <span class="row-title">
              {post_huddl(post)}
              <span class="meta">
                {Occasion.label(post.occasion)} · {post.social_connection.channel_name}
              </span>
            </span>
          </div>
        </div>
      </section>

      <section :if={@group.is_public && @recent_posts != []} id="recent-social-posts" class="panel">
        <div class="panel-head">
          <div>
            <h2>Recent posts</h2>
          </div>
        </div>
        <div class="row-list">
          <div :for={post <- @recent_posts} id={"social-post-#{post.id}"} class="row social-post-row">
            <span class="social-post-time">{post_time(post.sent_at || post.due_at, post.huddl)}</span>
            <span class="row-title">
              {post_huddl(post)}
              <span class="meta">
                {Occasion.label(post.occasion)} · {post.social_connection.channel_name}
              </span>
            </span>
            <.pill :if={post.state == :not_sent} variant={:magenta}>Didn't send</.pill>
          </div>
        </div>
      </section>

      <.connect_place_dialog :if={@connect_dialog?} group={@group} />
      <.schedule_sheet
        :if={@schedule_editor}
        connection={@schedule_editor}
        form={@schedule_form}
        moments_form={@moments_form}
        group={@group}
        fresh?={@connected_id == @schedule_editor.id}
      />
      <.remove_connection_dialog :if={@removing_connection?} connection={@schedule_editor} />
    </Layouts.app>
    """
  end

  # When a post goes out, read in its huddl's time zone.
  defp post_time(at, huddl) do
    at |> DateTime.shift_zone!(huddl.time_zone) |> Calendar.strftime("%a, %b %-d, %-I:%M %p")
  end

  # The huddl a post is about, with its date when the post goes out on
  # another day.
  defp post_huddl(%{huddl: huddl} = post) do
    starts = DateTime.shift_zone!(huddl.starts_at, huddl.time_zone)
    due = DateTime.shift_zone!(post.due_at, huddl.time_zone)

    if DateTime.to_date(starts) == DateTime.to_date(due),
      do: huddl.title,
      else: "#{huddl.title} · #{Calendar.strftime(starts, "%a, %b %-d")}"
  end

  defp state_label(:posting), do: "Posting"
  defp state_label(:paused), do: "Paused"
  defp state_label(:needs_reconnecting), do: "Needs reconnecting"

  defp state_variant(:posting), do: :cyan
  defp state_variant(:paused), do: :muted
  defp state_variant(:needs_reconnecting), do: :warn

  @not_yet [
    {"Bluesky", "Free to post to, and links work. The next one to add."},
    {"Mastodon", "Free to post to, and links work."},
    {"X", "X charges huddlz for every post that carries a link."},
    {"Instagram", "Posts can't carry a link, and Meta has to review huddlz first."}
  ]

  attr :group, :map, required: true

  defp connect_place_dialog(assigns) do
    assigns =
      assigns
      |> assign(:not_yet, @not_yet)
      |> assign(:tiles, [
        {:slack, "S", "Pick the workspace and channel on Slack's own screen."},
        {:discord, "D", "Pick the server and channel on Discord's own screen."}
      ])

    ~H"""
    <.modal id="connect-place-dialog" show on_cancel={JS.push("close_connect_dialog")}>
      <div class="pr-8">
        <h2 id="connect-place-dialog-title" class="text-xl font-bold">Connect a place</h2>
        <p class="mt-2 muted">Where should huddlz post for {@group.name}?</p>
      </div>
      <div class="place-tiles mt-5">
        <%= for {kind, mark, line} <- @tiles do %>
          <.link
            :if={Social.configured?(kind)}
            id={"connect-#{kind}"}
            class="place-tile"
            href={~p"/organize/#{@group.slug}/social/connect/#{kind}"}
          >
            <span class={"place-mark #{kind}"} aria-hidden="true">{mark}</span>
            <span class="place-tile-name">{Kind.label(kind)}</span>
            <span class="place-tile-line">{line}</span>
          </.link>
          <div
            :if={!Social.configured?(kind)}
            id={"connect-#{kind}"}
            class="place-tile place-tile-off"
          >
            <span class={"place-mark #{kind}"} aria-hidden="true">{mark}</span>
            <span class="place-tile-name">{Kind.label(kind)}</span>
            <span class="place-tile-line">Not set up on this server yet.</span>
          </div>
        <% end %>
      </div>
      <ul class="not-yet-list mt-4">
        <li :for={{name, why} <- @not_yet}>
          <span class="not-yet-name">{name}</span>
          <span class="muted">{why}</span>
          <span class="pill muted">Not yet</span>
        </li>
      </ul>
      <p class="mt-4 muted text-sm">
        One social connection is one channel. Connect again to post to another.
      </p>
    </.modal>
    """
  end

  attr :connection, :map, required: true

  defp remove_connection_dialog(assigns) do
    ~H"""
    <.modal id="remove-connection-dialog" show on_cancel={JS.push("cancel_remove_connection")}>
      <div class="pr-8">
        <h2 id="remove-connection-dialog-title" class="text-xl font-bold">
          Remove {SocialConnection.place(@connection)}?
        </h2>
        <p class="mt-3 muted">
          huddlz stops posting there. Connecting it again goes through {Kind.label(@connection.kind)}'s own screen.
        </p>
      </div>
      <div class="form-foot mt-6">
        <.button id="remove-connection-cancel" type="button" phx-click="cancel_remove_connection">
          Cancel
        </.button>
        <.button
          id="remove-connection-confirm"
          type="button"
          variant={:destructive}
          phx-click="remove_connection"
        >
          Remove connection
        </.button>
      </div>
    </.modal>
    """
  end

  attr :connection, :map, required: true
  attr :group, :map, required: true
  attr :fresh?, :boolean, default: false

  attr :form, :any, required: true
  attr :moments_form, :any, required: true

  defp schedule_sheet(assigns) do
    assigns =
      assigns
      |> assign(:moments, Moment.values())
      |> assign(:preview, preview_text(assigns.group, assigns.form[:opening_line].value))

    ~H"""
    <.modal id="schedule-sheet" show on_cancel={JS.push("close_schedule")}>
      <div class="pr-8">
        <h2 id="schedule-sheet-title" class="text-xl font-bold">Choose when it posts</h2>
        <p class="mt-2 muted">
          {SocialConnection.place(@connection)} · {@connection.workspace_name}. This applies to every public huddl from now on.
        </p>
      </div>
      <.form
        for={@form}
        id="schedule-form"
        phx-change="save_schedule"
        phx-submit="finish_schedule"
        class="mt-5"
      >
        <fieldset :if={@connection.kind == :discord} class="place-names">
          <legend class="form-label">What to call it</legend>
          <p class="muted text-sm">
            Discord shares only the server and channel ids, so name them the way your members would.
          </p>
          <div class="place-names-fields">
            <.input
              field={@form[:workspace_name]}
              id="place-server-name"
              label="Server name"
              phx-debounce="300"
            />
            <.input
              field={@form[:channel_name]}
              id="place-channel-name"
              label="Channel name"
              phx-debounce="300"
            />
          </div>
        </fieldset>
        <fieldset class="schedule-moments">
          <legend class="form-label">Social schedule</legend>
          <div :for={moment <- @moments} class="schedule-moment">
            <.toggle field={@moments_form[moment]} label={Moment.label(moment)} labelled_externally />
            <span>
              <label for={@moments_form[moment].id} class="schedule-moment-name">{Moment.label(moment)}</label>
              <span :if={Moment.hint(moment) != ""} class="muted">{Moment.hint(moment)}</span>
            </span>
          </div>
          <p class="muted text-sm">
            If a posted huddl is cancelled or moved, huddlz always posts a short follow-up here.
          </p>
        </fieldset>
        <div class="mt-4">
          <.input
            field={@form[:opening_line]}
            id="opening-line"
            label="Opening line"
            placeholder="Optional. For example: This week at Elixir Nashville:"
            help="Up to 140 characters."
            phx-debounce="300"
          />
        </div>
        <p class="muted text-sm mt-2">
          Changes save as you make them and show in the group's activity.
        </p>
        <section
          id="social-post-preview"
          aria-label="Morning-of post preview"
          class="mt-5 rounded-xl border border-base-content/15 bg-base-content/5 p-4"
        >
          <h3 class="font-semibold">Morning-of post preview</h3>
          <p class="muted text-sm mt-1">
            An example with your opening line. Each post uses the huddl's own details and local time.
          </p>
          <p class="mt-3 text-sm whitespace-pre-wrap break-words">{@preview}</p>
        </section>
        <div class="form-foot schedule-actions mt-5">
          <.button
            id="remove-connection"
            type="button"
            variant={:destructive}
            phx-click="ask_remove_connection"
          >
            Remove
          </.button>
          <.link
            href={~p"/organize/#{@group.slug}/social/reconnect/#{@connection.id}"}
            class="btn-secondary"
          >Reconnect</.link>
          <.button id="send-test-post" type="button" variant={:secondary} phx-click="send_test_post">
            Send a test post
          </.button>
          <.button id="finish-schedule" type="submit" variant={:primary}>
            {if @fresh?, do: "Start posting", else: "Done"}
          </.button>
        </div>
      </.form>
    </.modal>
    """
  end
end

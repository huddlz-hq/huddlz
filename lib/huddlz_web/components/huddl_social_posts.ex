defmodule HuddlzWeb.Components.HuddlSocialPosts do
  @moduledoc """
  The Social posts panel on a huddl's page in the organize workspace: one
  block per social connection, each with a switch to post the huddl there
  or skip it, the huddl's posts there with their times, and Post now; then
  a line to copy the post for places huddlz can't reach. With no
  connections the panel is only the copy line.

  Times are read in the huddl's time zone. The panel's events
  (`toggle_social_skip`, `post_social_now`) are handled by the page.
  """

  use Phoenix.Component

  import HuddlzWeb.Components.Icon
  import HuddlzWeb.Components.Input, only: [toggle: 1]
  import HuddlzWeb.Components.Pill

  alias Huddlz.Communities.SocialConnection.Kind
  alias Huddlz.Communities.SocialPost.Occasion

  attr :huddl, :map, required: true
  attr :connections, :list, required: true
  attr :posts, :list, required: true
  attr :skipped_ids, :list, required: true
  attr :copy_text, :string, required: true
  attr :steerable?, :boolean, required: true, doc: "whether the switches and Post now show"

  def social_posts_panel(assigns) do
    ~H"""
    <section id="social-posts" class="panel social-posts" aria-labelledby="social-posts-title">
      <div class="panel-head">
        <div>
          <h2 id="social-posts-title">Social posts</h2>
          <div :if={@connections != []} class="panel-sub">
            Times are in {zone_abbr(@huddl)}.
          </div>
        </div>
      </div>
      <div
        :for={connection <- @connections}
        id={"social-posts-connection-#{connection.id}"}
        class="social-posts-place"
      >
        <.place_head
          connection={connection}
          skipped?={connection.id in @skipped_ids}
          steerable?={@steerable?}
        />
        <.place_body
          connection={connection}
          huddl={@huddl}
          skipped?={connection.id in @skipped_ids}
          posts={Enum.filter(@posts, &(&1.social_connection_id == connection.id))}
          steerable?={@steerable?}
        />
      </div>
      <div class="social-posts-copy">
        <span class="muted">{copy_line(@connections)}</span>
        <button
          type="button"
          id="social-posts-copy"
          data-value={@copy_text}
          class="btn-secondary btn-sm"
        >
          <.icon name="hero-document-duplicate" class="size-4" />
          <span
            id="social-posts-copy-label"
            phx-hook="ClipboardCopy"
            phx-update="ignore"
            aria-live="polite"
          >Copy post</span>
        </button>
      </div>
    </section>
    """
  end

  attr :connection, :map, required: true
  attr :skipped?, :boolean, required: true
  attr :steerable?, :boolean, required: true

  defp place_head(assigns) do
    # One field per connection, named by its id, so each switch is its own.
    id = assigns.connection.id

    assigns =
      assigns
      |> assign(:form, to_form(%{id => to_string(!assigns.skipped?)}, as: :steer, id: "steer"))
      |> assign(:id, id)

    ~H"""
    <div class="social-posts-place-head">
      <span class={["place-mark", Atom.to_string(@connection.kind)]} aria-hidden="true">
        {String.first(Kind.label(@connection.kind))}
      </span>
      <span class="row-title">
        {@connection.channel_name}
        <span class="meta">{Kind.label(@connection.kind)} · {@connection.workspace_name}</span>
      </span>
      <.form
        :if={@steerable?}
        for={@form}
        id={"steer-form-#{@connection.id}"}
        phx-change="toggle_social_skip"
      >
        <label for={@form[@id].id} class="sr-only">
          Post this huddl to {@connection.channel_name}
        </label>
        <.toggle
          field={@form[@id]}
          label={"Post this huddl to #{@connection.channel_name}"}
          labelled_externally
        />
      </.form>
    </div>
    """
  end

  attr :connection, :map, required: true
  attr :huddl, :map, required: true
  attr :skipped?, :boolean, required: true
  attr :posts, :list, required: true
  attr :steerable?, :boolean, required: true

  defp place_body(%{skipped?: true} = assigns) do
    ~H"""
    <p class="social-posts-note">Skipped for this huddl.</p>
    """
  end

  defp place_body(%{connection: %{state: :paused}} = assigns) do
    ~H"""
    <p class="social-posts-note">Paused. Nothing will post until it is resumed.</p>
    """
  end

  defp place_body(%{connection: %{state: :needs_reconnecting}} = assigns) do
    ~H"""
    <p class="social-posts-note">
      Needs reconnecting. Nothing will post until the group owner reconnects it.
    </p>
    """
  end

  defp place_body(assigns) do
    ~H"""
    <p :if={@posts == []} class="social-posts-note">
      Nothing planned: none of its moments are still ahead for this huddl.
    </p>
    <ol :if={@posts != []} class="social-posts-list">
      <li :for={post <- @posts} id={"huddl-social-post-#{post.id}"} class="social-posts-post">
        <span class="social-post-time">{post_time(post, @huddl)}</span>
        <span>{Occasion.label(post.occasion)}</span>
        <.pill :if={post.state == :sent} variant={:cyan}>Sent</.pill>
        <.pill :if={post.state == :not_sent} variant={:magenta}>Didn't send</.pill>
      </li>
    </ol>
    <div :if={@steerable?} class="social-posts-actions">
      <button
        type="button"
        class="btn-secondary btn-sm"
        phx-click="post_social_now"
        phx-value-id={@connection.id}
      >
        <.icon name="hero-paper-airplane" class="size-4" /> Post now
      </button>
    </div>
    """
  end

  defp copy_line([]), do: "Copy the post to paste into a chat or channel."
  defp copy_line(_connections), do: "Posting somewhere huddlz can't reach? Copy the same words."

  # When a post went out, or will.
  defp post_time(post, huddl) do
    (post.sent_at || post.due_at)
    |> DateTime.shift_zone!(huddl.time_zone)
    |> Calendar.strftime("%a %-d %b, %-I:%M %p")
  end

  defp zone_abbr(huddl), do: DateTime.shift_zone!(huddl.starts_at, huddl.time_zone).zone_abbr
end

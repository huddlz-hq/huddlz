defmodule HuddlzWeb.OrganizeLive.Workspace do
  @moduledoc "Group access and archival status shared by organizer pages."
  use HuddlzWeb, :html

  import Phoenix.LiveView, only: [connected?: 1, put_flash: 3, push_navigate: 2]

  alias Huddlz.Communities
  alias Huddlz.Communities.MembershipEvents

  def open(socket, slug) do
    load_group(socket, slug, "That group doesn't exist, or you don't organize it.")
  end

  def refresh(socket) do
    group = socket.assigns.group
    load_group(socket, group.slug, "Your organizer access to #{group.name} has changed.")
  end

  defp load_group(socket, slug, error_message) do
    user = socket.assigns.current_user

    case Communities.get_group_for_organize(slug,
           actor: user,
           load: [:current_image_url, :member_count]
         ) do
      {:ok, %Communities.Group{} = group} ->
        if connected?(socket) && socket.assigns[:subscribed_group_id] != group.id do
          :ok = MembershipEvents.subscribe(group.id)
        end

        {:ok,
         assign(socket,
           group: group,
           subscribed_group_id: group.id,
           page_title: "#{group.name} · Organizer"
         )}

      _ ->
        {:error, socket |> put_flash(:error, error_message) |> push_navigate(to: ~p"/organize")}
    end
  end

  attr :group, :map, required: true
  attr :current_user, :map, required: true

  def archived_banner(assigns) do
    ~H"""
    <section
      :if={@group && @group.archived_at}
      id="organizer-archived-banner"
      class="panel mb-6"
      role="status"
    >
      <h2>This group is archived</h2>
      <p>History is read-only. Ownership can transfer without reopening the group.</p>
      <.link
        :if={@group.owner_id == @current_user.id}
        navigate={~p"/groups/#{@group.slug}/edit"}
        class="btn-secondary"
      >Manage archival</.link>
    </section>
    """
  end
end

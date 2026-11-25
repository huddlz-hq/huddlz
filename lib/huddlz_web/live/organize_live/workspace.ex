defmodule HuddlzWeb.OrganizeLive.Workspace do
  @moduledoc "Group access and archival status shared by organizer pages."
  use HuddlzWeb, :html

  import Phoenix.LiveView, only: [connected?: 1, put_flash: 3, push_navigate: 2]

  alias Huddlz.Communities
  alias Huddlz.Communities.MembershipEvents

  def open(socket, slug) do
    result = Communities.get_group_for_organize(slug, read_options(socket))
    assign_group(socket, result, "That group doesn't exist, or you don't organize it.")
  end

  def refresh(socket) do
    group = socket.assigns.group
    result = Communities.get_group_for_organize_by_id(group.id, read_options(socket))
    assign_group(socket, result, "Your organizer access to #{group.name} has changed.")
  end

  defp read_options(socket) do
    [actor: socket.assigns.current_user, load: [:current_image_url, :member_count]]
  end

  defp assign_group(socket, {:ok, %Communities.Group{} = group}, _error_message) do
    if connected?(socket) && socket.assigns[:subscribed_group_id] != group.id do
      :ok = MembershipEvents.subscribe(group.id)
    end

    {:ok,
     assign(socket,
       group: group,
       subscribed_group_id: group.id,
       page_title: "#{group.name} · Organizer"
     )}
  end

  defp assign_group(socket, _result, error_message) do
    {:error, socket |> put_flash(:error, error_message) |> push_navigate(to: ~p"/organize")}
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

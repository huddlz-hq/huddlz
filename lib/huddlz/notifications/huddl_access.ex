defmodule Huddlz.Notifications.HuddlAccess do
  @moduledoc """
  Resolves private virtual access for the recipient when an email is built.
  Queued payloads are never trusted as a source of meeting links.
  """

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl

  def for_recipient!(id, user) do
    # Notification metadata remains available for queued confirmations and reminders,
    # but private access must be resolved through the recipient's current permissions.
    huddl = Ash.get!(Huddl, id, authorize?: false, load: [:group])
    %{huddl | virtual_link: virtual_link(id, user)}
  end

  def virtual_link(id, user) when is_binary(id) do
    case Communities.get_huddl(id, actor: user, load: :visible_virtual_link) do
      {:ok, huddl} -> huddl.visible_virtual_link
      {:error, _} -> nil
    end
  end

  def virtual_link(_id, _user), do: nil
end

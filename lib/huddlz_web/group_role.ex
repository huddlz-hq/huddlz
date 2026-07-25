defmodule HuddlzWeb.GroupRole do
  @moduledoc """
  Presents a person's actual membership role consistently across group UI.

  Permission checks remain the authority for available actions. These helpers
  only describe the persisted owner or membership relationship and therefore
  never turn an admin override into an implied group role.
  """

  def for_group(%{owner_id: user_id}, %{id: user_id}), do: :owner

  def for_group(%{group_members: memberships}, %{id: user_id}) when is_list(memberships) do
    case Enum.find(memberships, &(&1.user_id == user_id)) do
      %{role: role} -> role
      nil -> nil
    end
  end

  def for_group(_group, _user), do: nil

  def label(:owner), do: "Owner"
  def label(:organizer), do: "Organizer"
  def label(:member), do: "Member"
  def label(_role), do: nil

  def pill_variant(:owner), do: :cyan
  def pill_variant(:organizer), do: :warn
  def pill_variant(:member), do: :magenta

  def card_class(:owner), do: "hybrid"
  def card_class(:organizer), do: "online"
  def card_class(:member), do: "in-person"
end

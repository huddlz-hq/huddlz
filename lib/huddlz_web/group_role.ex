defmodule HuddlzWeb.GroupRole do
  @moduledoc "Shared display names for persisted group membership roles."

  def label(:owner), do: "Owner"
  def label(:organizer), do: "Organizer"
  def label(:member), do: "Member"
  def label(_), do: nil
end

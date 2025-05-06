defmodule Huddlz.Soirees do
  @moduledoc """
  DEPRECATED: This module is deprecated in favor of Huddlz.Huddls
  """
  use Ash.Domain,
    otp_app: :huddlz,
    validate_config_inclusion?: false

  # This is now deprecated, but we keep it for backward compatibility
  resources do
    resource Huddlz.Soirees.Soiree
  end
  
  def get_upcoming! do
    Huddlz.Huddls.get_upcoming!()
  end
  
  def search!(query) do
    Huddlz.Huddls.search!(query)
  end
  
  def get_by_status!(status) do
    Huddlz.Huddls.get_by_status!(status)
  end
end

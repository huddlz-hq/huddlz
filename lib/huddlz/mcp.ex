defmodule Huddlz.Mcp do
  @moduledoc "The allowlisted, actor-bound interface for agent clients."
  use Ash.Domain, otp_app: :huddlz, extensions: [AshAi]

  tools do
    tool(:search_groups, Huddlz.Mcp.Tools, :search_groups)
    tool(:my_groups, Huddlz.Mcp.Tools, :my_groups)
    tool(:get_group, Huddlz.Mcp.Tools, :get_group)
    tool(:join_group, Huddlz.Mcp.Tools, :join_group)
    tool(:leave_group, Huddlz.Mcp.Tools, :leave_group)
    tool(:join_waitlist, Huddlz.Mcp.Tools, :join_waitlist)
    tool(:cancel_rsvp, Huddlz.Mcp.Tools, :cancel_rsvp)
    tool(:get_huddl, Huddlz.Mcp.Tools, :get_huddl)
    tool(:rsvp_huddl, Huddlz.Mcp.Tools, :rsvp_huddl)
    tool(:search_huddlz, Huddlz.Mcp.Tools, :search_huddlz)
    tool(:get_search_context, Huddlz.Mcp.Tools, :get_search_context)
  end

  resources do
    resource Huddlz.Mcp.Tools
  end
end

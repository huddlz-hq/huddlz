defmodule Huddlz.Admin.PlatformOverview do
  @moduledoc """
  The admin overview's figures as an action for the huddlz dashboard.
  Only administrators may run it; the figures themselves come from
  `Huddlz.Admin.PlatformStats`.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Admin,
    authorizers: [Ash.Policy.Authorizer]

  alias Huddlz.Admin.PlatformStats
  alias Huddlz.Communities.Periods

  actions do
    action :overview, :map do
      description """
      Platform-wide overview figures for a period: people and how many
      signed up, active people and when measuring them began, groups and
      how many held a huddl, huddlz held, RSVPs and show rate against the
      period before, the most active groups, what is coming up, RSVPs from
      people who had not joined the group, and huddlz copied from another.
      Periods are "30d", "90d" (default) and "12m".
      """

      argument :period, :string do
        allow_nil? true
        default "90d"
      end

      run fn input, context ->
        period = input |> Ash.ActionInput.get_argument(:period) |> Periods.parse_period()
        {:ok, PlatformStats.compute(period, context.actor)}
      end
    end
  end

  policies do
    policy action(:overview) do
      description "Only administrators can read the platform figures"
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end

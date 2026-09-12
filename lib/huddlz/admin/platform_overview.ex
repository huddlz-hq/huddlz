defmodule Huddlz.Admin.PlatformOverview do
  @moduledoc """
  The admin overview's figures as an action, so they are reachable from
  the API with an actor like everything else. Only administrators may
  run it; the figures themselves come from `Huddlz.Admin.PlatformStats`.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Admin,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  alias Huddlz.Admin.PlatformStats
  alias Huddlz.Communities.Periods

  graphql do
    queries do
      action :platform_overview, :overview
    end
  end

  actions do
    action :overview, :map do
      description """
      Platform-wide overview figures for a period: people and how many
      signed up, people active, groups and how many held a huddl, huddlz
      held, RSVPs and show rate against the period before, the most
      active groups and what is coming up. Periods are "30d", "90d"
      (default) and "12m".
      """

      argument :period, :string do
        allow_nil? true
        default "90d"
      end

      run fn input, _context ->
        period = input |> Ash.ActionInput.get_argument(:period) |> Periods.parse_period()
        {:ok, PlatformStats.compute(period)}
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

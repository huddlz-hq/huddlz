defmodule Huddlz.Admin do
  @moduledoc """
  Platform administration: the figures across every group and account
  that only administrators may read.
  """

  use Ash.Domain,
    otp_app: :huddlz,
    extensions: [AshGraphql.Domain]

  resources do
    resource Huddlz.Admin.PlatformOverview do
      define :platform_overview, action: :overview, args: [{:optional, :period}]
    end

    resource Huddlz.Admin.Impersonation do
      define :start_impersonation, action: :start, args: [:user_id]
      define :stop_impersonation, action: :stop
      define :resolve_impersonation_session, action: :resolve_session, args: [:id]
    end
  end
end

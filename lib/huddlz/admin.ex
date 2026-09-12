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
  end
end

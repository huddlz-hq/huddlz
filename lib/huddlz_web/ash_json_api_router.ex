defmodule HuddlzWeb.AshJsonApiRouter do
  @moduledoc false
  use AshJsonApi.Router,
    domains: [Huddlz.Communities],
    open_api: "/open_api"
end

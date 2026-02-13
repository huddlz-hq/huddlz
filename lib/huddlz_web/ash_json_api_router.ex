defmodule HuddlzWeb.AshJsonApiRouter do
  @moduledoc false
  use AshJsonApi.Router,
    domains: [Huddlz.Communities],
    open_api: "/open_api",
    modify_open_api: {__MODULE__, :modify_open_api, []}

  def modify_open_api(spec, _, _) do
    %{
      spec
      | components:
          Map.put(spec.components || %{}, :securitySchemes, %{
            "bearer" => %OpenApiSpex.SecurityScheme{
              type: "http",
              scheme: "bearer",
              bearerFormat: "JWT"
            }
          }),
        security: [%{"bearer" => []}]
    }
  end
end

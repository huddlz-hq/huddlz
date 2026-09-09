defmodule Huddlz.Accounts.Profile do
  @moduledoc """
  The authenticated member's private profile contract for API clients.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type "profile"

    routes do
      route :get, "/profile", :get
    end
  end

  actions do
    action :get, :map do
      description "Read your current private profile and saved home search defaults."

      constraints fields: [
                    id: [type: :uuid, allow_nil?: false],
                    display_name: [type: :string],
                    email: [type: :string, allow_nil?: false],
                    search_defaults: [
                      type: :map,
                      allow_nil?: false,
                      constraints: [
                        fields: [
                          home_location: [
                            type: :map,
                            description:
                              "Saved home search location, or null when unset or incomplete.",
                            constraints: [
                              fields: [
                                label: [type: :string],
                                latitude: [type: :float, allow_nil?: false],
                                longitude: [type: :float, allow_nil?: false],
                                time_zone: [
                                  type: :string,
                                  allow_nil?: false,
                                  description:
                                    "Canonical IANA zone for relative calendar searches."
                                ]
                              ]
                            ]
                          ],
                          distance_miles: [
                            type: :integer,
                            allow_nil?: false,
                            description:
                              "Default search radius; not a persisted member preference."
                          ]
                        ]
                      ]
                    ]
                  ]

      run Huddlz.Accounts.Profile.Actions.Get
    end
  end

  policies do
    policy action(:get) do
      authorize_if actor_present()
    end
  end
end

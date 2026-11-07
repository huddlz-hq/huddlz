defmodule Huddlz.Communities.SocialSkip do
  @moduledoc """
  One huddl left off one social connection: the schedule is the rule, and
  an organizer has made this huddl the exception. While a skip stands the
  connection posts nothing about the huddl, follow-ups included. Written
  by the huddl's `:skip_social_connection` and `:unskip_social_connection`
  actions; organizers of the group read them.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  graphql do
    type :social_skip

    queries do
      list :huddl_social_skips, :for_huddl
    end
  end

  postgres do
    table "social_skips"
    repo Huddlz.Repo

    references do
      reference :social_connection, on_delete: :delete
      reference :huddl, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :skip do
      description "Leave the huddl off the connection; skipping twice changes nothing"
      accept [:social_connection_id, :huddl_id]
      upsert? true
      upsert_identity :unique_skip
      upsert_fields []
    end

    destroy :unskip do
      description "Post the huddl on the connection again"
    end

    read :for_huddl do
      description "The connections a huddl is skipped on"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      filter expr(huddl_id == ^arg(:huddl_id))
      prepare build(load: [:social_connection])
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(social_connection.group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(
                       social_connection.group.group_members,
                       user_id == ^actor(:id) and role == :organizer
                     )
                   )
    end
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :social_connection, Huddlz.Communities.SocialConnection do
      allow_nil? false
      public? true
    end

    belongs_to :huddl, Huddlz.Communities.Huddl do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_skip, [:social_connection_id, :huddl_id]
  end
end

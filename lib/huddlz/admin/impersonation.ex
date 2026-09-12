defmodule Huddlz.Admin.Impersonation do
  @moduledoc """
  One browser impersonation: its initiating administrator, target person,
  start and stop. Shared audit versions and group activity reference this
  record directly.

  Only administrators start impersonation. Self-targeting and administrator
  targets are unsupported in this release; the initiator may stop it.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Admin,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Huddlz.Accounts.User

  postgres do
    table "impersonations"
    repo Huddlz.Repo

    references do
      reference :admin, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    action :resolve_session, :struct do
      description "Resolve an active browser impersonation belonging to the current actor"
      constraints instance_of: __MODULE__
      allow_nil? true
      argument :id, :uuid, allow_nil?: false
      run Huddlz.Admin.Impersonation.ResolveSession
    end

    create :start do
      description "Begin viewing huddlz as the given person"
      accept [:user_id]

      change relate_actor(:admin)

      validate fn changeset, %{actor: actor} ->
        user_id = Ash.Changeset.get_attribute(changeset, :user_id)

        cond do
          is_nil(user_id) ->
            :ok

          actor && user_id == actor.id ->
            {:error, field: :user_id, message: "You are already yourself."}

          true ->
            case Ash.get(User, user_id, authorize?: false) do
              {:ok, %User{role: :admin}} ->
                {:error, field: :user_id, message: "Administrators cannot be viewed as."}

              {:ok, _user} ->
                :ok

              {:error, _} ->
                {:error, field: :user_id, message: "That person no longer exists."}
            end
        end
      end
    end

    update :stop do
      description "Stop viewing as the person and stamp when"
      accept []
      change set_attribute(:ended_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action(:resolve_session) do
      authorize_if actor_present()
    end

    policy action(:start) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:stop) do
      authorize_if expr(admin_id == ^actor(:id))
    end

    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :started_at
    attribute :ended_at, :utc_datetime_usec
  end

  relationships do
    belongs_to :admin, User do
      allow_nil? false
    end

    belongs_to :user, User do
      allow_nil? false
    end
  end
end

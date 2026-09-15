defmodule Huddlz.Admin.AccountReview do
  @moduledoc """
  An account and its remaining community responsibilities for staff review.
  Community records are read with the administrator's ordinary permissions.
  """
  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Admin,
    authorizers: [Ash.Policy.Authorizer]

  alias Huddlz.Accounts
  alias Huddlz.Communities.{Group, Huddl}

  require Ash.Query

  actions do
    action :review, :map do
      argument :user_id, :uuid, allow_nil?: false

      run fn input, context ->
        with {:ok, user} <-
               Accounts.get_user(input.arguments.user_id,
                 actor: context.actor,
                 load: [:suspended_by, :open_report_count]
               ),
             {:ok, groups} <- owned_groups(user.id, context.actor),
             {:ok, huddlz} <- remaining_huddlz(user.id, context.actor) do
          {:ok, %{user: user, groups: groups, huddlz: huddlz}}
        end
      end
    end
  end

  policies do
    policy action(:review) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  defp owned_groups(user_id, actor) do
    Group
    |> Ash.Query.for_read(:read_with_archived, %{}, actor: actor)
    |> Ash.Query.filter(owner_id == ^user_id and is_nil(archived_at))
    |> Ash.Query.sort(name: :asc)
    |> Ash.read()
  end

  defp remaining_huddlz(user_id, actor) do
    Huddl
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.filter(
      (creator_id == ^user_id or group.owner_id == ^user_id) and
        lifecycle_state in [:draft, :published] and ends_at > now()
    )
    |> Ash.Query.sort(starts_at: :asc)
    |> Ash.read()
  end
end

defmodule Huddlz.Audit.Version do
  @moduledoc """
  Internal access and retention configuration for AshPaperTrail versions.

  Every version keeps 90 days for troubleshooting. Participation history
  outlives that: a resource mixes in `keep: :all` to keep its whole stream
  for two years, or `keep: [actions]` to keep only those actions' versions
  that long. Two years is a twelve-month period plus the twelve months it
  is compared with. See ADR 0007.
  """

  @troubleshooting_days 90
  @participation_days 730

  def troubleshooting_days, do: @troubleshooting_days
  def participation_days, do: @participation_days

  def mixin(opts \\ []) do
    expired = expired(Keyword.get(opts, :keep, []))

    quote do
      policies do
        policy always() do
          access_type :strict
          forbid_if always()
        end
      end

      actions do
        destroy :expire do
          accept []
          argument :now, :utc_datetime_usec, allow_nil?: false, default: &DateTime.utc_now/0
          change filter(unquote(expired))
        end
      end

      changes do
        change Huddlz.Audit.AttributeImpersonation, on: [:create]
        change Huddlz.Audit.ClearSystemActor, on: [:create]
      end

      relationships do
        belongs_to :impersonator, Huddlz.Accounts.User do
          define_attribute? false
          domain Huddlz.Accounts
        end
      end

      postgres do
        references do
          reference :impersonator, on_delete: :nilify
        end

        custom_indexes do
          index [:version_inserted_at]
        end
      end
    end
  end

  # The filter behind `:expire`: what the daily prune may remove now.
  defp expired([]) do
    quote do
      expr(
        ^ref(:version_inserted_at) <
          datetime_add(^arg(:now), -unquote(@troubleshooting_days), :day)
      )
    end
  end

  defp expired(:all) do
    quote do
      expr(
        ^ref(:version_inserted_at) < datetime_add(^arg(:now), -unquote(@participation_days), :day)
      )
    end
  end

  defp expired(actions) when is_list(actions) do
    quote do
      expr(
        ^ref(:version_inserted_at) < datetime_add(^arg(:now), -unquote(@participation_days), :day) or
          (^ref(:version_inserted_at) <
             datetime_add(^arg(:now), -unquote(@troubleshooting_days), :day) and
             ^ref(:version_action_name) not in unquote(actions))
      )
    end
  end
end

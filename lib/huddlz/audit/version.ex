defmodule Huddlz.Audit.Version do
  @moduledoc "Internal access and uniform two-year (730-day) retention for AshPaperTrail versions."

  def mixin do
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
          change filter(expr(^ref(:version_inserted_at) < datetime_add(^arg(:now), -730, :day)))
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
end

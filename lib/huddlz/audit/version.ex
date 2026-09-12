defmodule Huddlz.Audit.Version do
  @moduledoc "Internal access and retention configuration for AshPaperTrail versions."

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
        end
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

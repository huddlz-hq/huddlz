defmodule Huddlz.Audit.AttributeImpersonation do
  @moduledoc "Connects trusted browser-session attribution to PaperTrail versions."
  use Ash.Resource.Change

  alias Huddlz.Accounts.User
  alias Huddlz.Admin.Impersonation

  @impl true
  def change(changeset, _opts, %{
        actor: %User{
          id: user_id,
          __metadata__: %{
            impersonation: %Impersonation{
              id: id,
              admin_id: admin_id,
              user_id: user_id,
              ended_at: nil
            }
          }
        }
      }) do
    changeset
    |> Ash.Changeset.force_change_attribute(:impersonation_id, id)
    |> Ash.Changeset.force_change_attribute(:impersonator_id, admin_id)
  end

  def change(changeset, _opts, _context), do: changeset
end

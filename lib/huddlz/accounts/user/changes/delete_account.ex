defmodule Huddlz.Accounts.User.Changes.DeleteAccount do
  @moduledoc """
  Everything a person's own account deletion sets in motion.

  The row stays so that records which must keep an author (a huddl's
  creator, a past attendance, an audit version) still point somewhere, but
  nothing personal remains on it: the email becomes an unreachable
  placeholder, the name reads "Deleted member", and the password, home
  location, pending email change and preferences are cleared. The person
  can register again later with the same address.

  Inside the transaction: every stored token is revoked, API keys are
  destroyed, profile pictures are removed, upcoming RSVP and waitlist spots
  are released, and the person leaves every group they do not own. Groups
  they own are archived, so members keep read-only history; archiving needs
  no upcoming huddlz, so those are cancelled first and their attendees told.

  Everything a nested write records is attributed to the person through
  `Huddlz.Audit.nested_opts/2`.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts.{ApiKey, ProfilePicture, Token, User}
  alias Huddlz.Communities.{Group, GroupMember, Huddl, ReleaseSpots}

  require Ash.Query

  @display_name "Deleted member"
  @cancellation_reason "The organizer closed their huddlz account."

  @doc "The name a deleted account is shown as."
  def display_name, do: @display_name

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.force_change_attributes(%{
      email: "deleted-#{changeset.data.id}@deleted.huddlz.invalid",
      display_name: @display_name,
      hashed_password: nil,
      pending_email_change: nil,
      email_change_resends: [],
      confirmation_destination: nil,
      home_location: nil,
      home_latitude: nil,
      home_longitude: nil,
      home_time_zone: nil,
      notification_preferences: %{},
      deleted_at: DateTime.utc_now()
    })
    |> Ash.Changeset.after_action(&cut_ties/2)
  end

  defp cut_ties(changeset, %User{} = user) do
    opts = Huddlz.Audit.nested_opts(changeset)

    revoke_tokens(user)
    destroy_api_keys(user, opts)
    remove_profile_pictures(user, opts)
    ReleaseSpots.release_upcoming(user, opts)
    archive_owned_groups(user, opts)
    leave_groups(user, opts)
    {:ok, user}
  end

  defp revoke_tokens(user) do
    subject = AshAuthentication.user_to_subject(user)

    %{status: :success} =
      Token
      |> Ash.bulk_update(:revoke_all_stored_for_subject, %{subject: subject},
        authorize?: false,
        strategy: [:atomic, :atomic_batches, :stream],
        return_errors?: true,
        stop_on_error?: true
      )

    :ok
  end

  defp destroy_api_keys(user, opts) do
    ApiKey
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn key ->
      key
      |> Ash.Changeset.for_destroy(:destroy, %{}, opts)
      |> Ash.destroy!(authorize?: false)
    end)
  end

  defp remove_profile_pictures(user, opts) do
    ProfilePicture
    |> Ash.Query.filter(user_id == ^user.id and is_nil(deleted_at))
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn picture ->
      picture
      |> Ash.Changeset.for_update(:soft_delete, %{}, opts)
      |> Ash.update!(authorize?: false)
    end)
  end

  defp archive_owned_groups(user, opts) do
    Group
    |> Ash.Query.filter(owner_id == ^user.id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn group ->
      cancel_upcoming_huddlz(group, opts)

      group
      |> Ash.Changeset.for_destroy(:archive, %{}, opts)
      |> Ash.destroy!(authorize?: false)
    end)
  end

  defp cancel_upcoming_huddlz(group, opts) do
    Huddl
    |> Ash.Query.for_read(:archive_blockers, %{}, authorize?: false)
    |> Ash.Query.filter(group_id == ^group.id)
    |> Ash.read!()
    |> Enum.each(fn huddl ->
      huddl
      |> Ash.Changeset.for_update(:cancel, %{cancellation_reason: @cancellation_reason}, opts)
      |> Ash.update!(authorize?: false)
    end)
  end

  defp leave_groups(user, opts) do
    GroupMember
    |> Ash.Query.filter(user_id == ^user.id and role != :owner)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn membership ->
      membership
      |> Ash.Changeset.for_destroy(:leave_group, %{}, opts)
      |> Ash.destroy!(authorize?: false)
    end)
  end
end

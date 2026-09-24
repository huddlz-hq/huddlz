defmodule Huddlz.Accounts.SuspensionTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator

  alias AshAuthentication.TokenResource.Actions, as: Tokens
  alias Huddlz.Accounts
  alias Huddlz.Accounts.{Token, User}
  alias Huddlz.Communities
  alias Huddlz.Communities.{GroupMember, Huddl, HuddlAttendee}

  require Ash.Query

  setup do
    admin = generate(user(role: :admin, display_name: "Admin Alex"))
    person = generate(user(role: :user, display_name: "Crypto Kings Promo"))
    member = generate(user(role: :user, display_name: "Member Maya"))
    owner = generate(user(role: :user, display_name: "Owner Olive"))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    join!(group, person, :organizer)
    join!(group, member, :organizer)
    %{admin: admin, person: person, member: member, owner: owner, group: group}
  end

  describe "suspend" do
    test "needs a reason", %{admin: admin, person: person} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Accounts.suspend_user(person, "   ", actor: admin)

      assert Enum.any?(errors, &(&1.field == :reason))
      refute Ash.get!(User, person.id, authorize?: false).suspended_at
    end

    test "records who, when and why", %{admin: admin, person: person} do
      {:ok, suspended} = Accounts.suspend_user(person, "Repeated coin listings", actor: admin)

      assert %DateTime{} = suspended.suspended_at
      assert suspended.suspension_reason == "Repeated coin listings"
      assert suspended.suspended_by_id == admin.id
    end

    test "is for administrators only, never on themselves or each other", %{
      admin: admin,
      person: person,
      member: member
    } do
      other_admin = generate(user(role: :admin))

      assert {:error, %Ash.Error.Forbidden{}} = Accounts.suspend_user(person, "x", actor: member)
      assert {:error, %Ash.Error.Forbidden{}} = Accounts.suspend_user(admin, "x", actor: admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.suspend_user(other_admin, "x", actor: admin)
    end

    test "revokes every stored token and API key", %{admin: admin, person: person} do
      {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(person, %{}, domain: Accounts)

      key =
        Huddlz.Accounts.ApiKey
        |> Ash.Changeset.for_create(
          :create,
          %{name: "Test key", expires_at: DateTime.add(DateTime.utc_now(), 3600)},
          actor: person
        )
        |> Ash.create!()

      {:ok, _} = Accounts.suspend_user(person, "Spam", actor: admin)

      assert {:error, :token_revoked} = verify_and_check(token)

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.get(Huddlz.Accounts.ApiKey, key.id, authorize?: false)
    end

    test "releases upcoming spots, keeps their history and moves the waitlist", %{
      admin: admin,
      person: person,
      member: member,
      group: group
    } do
      huddl = generate(huddl(group_id: group.id, creator_id: person.id, actor: person))

      Huddlz.Repo.query!("UPDATE huddlz SET max_attendees = 1 WHERE id = $1", [
        Ecto.UUID.dump!(huddl.id)
      ])

      waitlist!(huddl, member)

      {:ok, _} = Accounts.suspend_user(person, "Spam", actor: admin)

      assert [%{user_id: user_id, waitlisted_at: nil}] = attendees(huddl.id)
      assert user_id == member.id

      released =
        HuddlAttendee.Version
        |> Ash.Query.filter(version_action_name == :cancel_rsvp)
        |> Ash.read!(authorize?: false)

      assert [%{actor_id: actor_id}] = released
      assert actor_id == admin.id
    end

    test "never promotes a suspended person from a waitlist", %{
      admin: admin,
      person: person,
      member: member,
      owner: owner,
      group: group
    } do
      huddl = generate(huddl(group_id: group.id, creator_id: member.id, actor: member))

      Huddlz.Repo.query!("UPDATE huddlz SET max_attendees = 1 WHERE id = $1", [
        Ecto.UUID.dump!(huddl.id)
      ])

      waitlist!(huddl, person)
      waitlist!(huddl, owner)

      {:ok, _} = Accounts.suspend_user(person, "Spam", actor: admin)
      huddl |> Ash.Changeset.for_update(:cancel_rsvp, %{}, actor: member) |> Ash.update!()

      assert [%{user_id: user_id, waitlisted_at: nil}] = attendees(huddl.id)
      assert user_id == owner.id
    end
  end

  describe "what others see" do
    test "member lists and counts leave a suspended account out", %{
      admin: admin,
      person: person,
      owner: owner,
      group: group
    } do
      {:ok, _} = Accounts.suspend_user(person, "Spam", actor: admin)

      names =
        Communities.get_by_group!(group.id, actor: owner, load: :user)
        |> Enum.map(& &1.user.display_name)

      refute "Crypto Kings Promo" in names
      assert "Suspended account" not in names
      assert Ash.load!(group, :member_count, authorize?: false).member_count == 2
    end

    test "a huddl creator reads as Suspended account to everyone but an administrator", %{
      admin: admin,
      person: person,
      member: member,
      group: group
    } do
      huddl = generate(huddl(group_id: group.id, creator_id: person.id, actor: person))
      {:ok, _} = Accounts.suspend_user(person, "Spam", actor: admin)

      seen_by_member =
        Ash.load!(Ash.get!(Huddl, huddl.id, actor: member), :creator, actor: member)

      assert seen_by_member.creator.display_name == "Suspended account"

      seen_by_admin = Ash.load!(Ash.get!(Huddl, huddl.id, actor: admin), :creator, actor: admin)
      assert seen_by_admin.creator.display_name == "Crypto Kings Promo"
    end

    test "past attendance keeps the row under the neutral label", %{
      admin: admin,
      person: person,
      member: member,
      group: group
    } do
      huddl = generate(past_huddl(group_id: group.id, creator_id: member.id))
      seed_rsvp!(huddl, person)
      seed_rsvp!(huddl, member)
      {:ok, _} = Accounts.suspend_user(person, "Spam", actor: admin)

      names =
        Communities.list_huddl_attendees!(huddl.id, actor: member, load: :display_name)
        |> Enum.map(& &1.display_name)

      assert "Suspended account" in names
      refute "Crypto Kings Promo" in names
    end
  end

  describe "restore" do
    test "clears the suspension without reviving credentials", %{admin: admin, person: person} do
      {:ok, token, _} = AshAuthentication.Jwt.token_for_user(person, %{}, domain: Accounts)
      {:ok, suspended} = Accounts.suspend_user(person, "Mistaken", actor: admin)
      {:ok, restored} = Accounts.restore_user(suspended, actor: admin)

      refute restored.suspended_at
      refute restored.suspension_reason
      refute restored.suspended_by_id
      assert {:error, :token_revoked} = verify_and_check(token)
    end

    test "is for administrators only", %{admin: admin, person: person, member: member} do
      {:ok, suspended} = Accounts.suspend_user(person, "Spam", actor: admin)
      assert {:error, %Ash.Error.Forbidden{}} = Accounts.restore_user(suspended, actor: member)
    end
  end

  defp join!(group, user, role) do
    Ash.Seed.seed!(GroupMember, %{group_id: group.id, user_id: user.id, role: role})
  end

  defp seed_rsvp!(huddl, user) do
    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: user.id})
    |> Ash.create!(authorize?: false)
  end

  defp attendees(huddl_id) do
    HuddlAttendee
    |> Ash.Query.filter(huddl_id == ^huddl_id)
    |> Ash.read!(authorize?: false)
  end

  defp waitlist!(huddl, user) do
    huddl |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: user) |> Ash.update!()
  end

  defp verify_and_check(token) do
    if Tokens.token_revoked?(Token, token),
      do: {:error, :token_revoked},
      else: {:ok, :live}
  end
end

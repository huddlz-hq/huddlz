defmodule Huddlz.Accounts.User.NotificationPreferencesTest do
  use Huddlz.DataCase, async: true

  describe "notification_preferences attribute" do
    test "defaults to an empty map for newly generated users" do
      user = generate(user())
      assert user.notification_preferences == %{}
    end
  end

  describe "update_notification_preferences action" do
    test "self can merge a partial map onto existing preferences" do
      user = generate(user())

      {:ok, after_first} =
        user
        |> Ash.Changeset.for_update(
          :update_notification_preferences,
          %{preferences: %{"huddl_reminder_24h" => false}},
          actor: user
        )
        |> Ash.update()

      assert after_first.notification_preferences == %{"huddl_reminder_24h" => false}

      {:ok, after_second} =
        after_first
        |> Ash.Changeset.for_update(
          :update_notification_preferences,
          %{preferences: %{"rsvp_received" => true}},
          actor: after_first
        )
        |> Ash.update()

      assert after_second.notification_preferences == %{
               "huddl_reminder_24h" => false,
               "rsvp_received" => true
             }
    end

    test "incoming keys overwrite same-key values; other keys are preserved" do
      user = generate(user())

      {:ok, seeded} =
        user
        |> Ash.Changeset.for_update(
          :update_notification_preferences,
          %{preferences: %{"huddl_reminder_24h" => false, "rsvp_received" => true}},
          actor: user
        )
        |> Ash.update()

      {:ok, updated} =
        seeded
        |> Ash.Changeset.for_update(
          :update_notification_preferences,
          %{preferences: %{"huddl_reminder_24h" => true}},
          actor: seeded
        )
        |> Ash.update()

      assert updated.notification_preferences == %{
               "huddl_reminder_24h" => true,
               "rsvp_received" => true
             }
    end

    test "another user cannot update someone else's preferences" do
      owner = generate(user())
      other = generate(user())

      assert_raise Ash.Error.Forbidden, fn ->
        owner
        |> Ash.Changeset.for_update(
          :update_notification_preferences,
          %{preferences: %{"huddl_reminder_24h" => false}},
          actor: other
        )
        |> Ash.update!()
      end
    end

    test "unauthenticated update is forbidden" do
      target = generate(user())

      assert_raise Ash.Error.Forbidden, fn ->
        target
        |> Ash.Changeset.for_update(:update_notification_preferences, %{
          preferences: %{"huddl_reminder_24h" => false}
        })
        |> Ash.update!()
      end
    end

    test "admin bypass policy lets admins update on behalf of users" do
      target = generate(user())
      admin = generate(user(role: :admin))

      {:ok, updated} =
        target
        |> Ash.Changeset.for_update(
          :update_notification_preferences,
          %{preferences: %{"huddl_reminder_24h" => false}},
          actor: admin
        )
        |> Ash.update()

      assert updated.notification_preferences == %{"huddl_reminder_24h" => false}
    end
  end
end

defmodule Huddlz.NotificationsTest do
  use Huddlz.DataCase, async: true
  import Swoosh.TestAssertions

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications

  describe "deliver/3 with a real sender" do
    test "sends for a transactional trigger with the live PasswordChanged sender" do
      user = generate(user(confirmed_at: DateTime.utc_now()))
      assert :sent == Notifications.deliver(user, :password_changed, %{})

      assert_email_sent(fn email ->
        email.subject == "Your huddlz password was changed" and
          email.to == [{"", to_string(user.email)}]
      end)
    end

    test "skips when the user has opted out of an activity trigger" do
      user = generate_user_with_prefs(%{"rsvp_received" => false})
      # The sender module for :rsvp_received does not exist yet — the
      # orchestrator must short-circuit before invoking it.
      assert :skipped == Notifications.deliver(user, :rsvp_received, %{})
      refute_email_sent()
    end

    test "skips activity triggers for unconfirmed users" do
      user = generate(user(confirmed_at: nil))
      assert :skipped == Notifications.deliver(user, :rsvp_received, %{})
      refute_email_sent()
    end
  end

  describe "should_deliver?/3" do
    test "transactional category always sends to a confirmed user" do
      user = generate(user())
      entry = transactional()
      assert Notifications.should_deliver?(user, :anything, entry)
    end

    test "transactional ignores the user's preferences" do
      user = generate_user_with_prefs(%{"anything" => false})
      entry = transactional()
      assert Notifications.should_deliver?(user, :anything, entry)
    end

    test "activity with default true and no preference sends" do
      user = generate(user())
      entry = activity(default: true)
      assert Notifications.should_deliver?(user, :rsvp_received, entry)
    end

    test "activity with default true sends when explicitly enabled" do
      user = generate_user_with_prefs(%{"rsvp_received" => true})
      entry = activity(default: true)
      assert Notifications.should_deliver?(user, :rsvp_received, entry)
    end

    test "activity skips when explicitly disabled" do
      user = generate_user_with_prefs(%{"rsvp_received" => false})
      entry = activity(default: true)
      refute Notifications.should_deliver?(user, :rsvp_received, entry)
    end

    test "digest with default false and no preference is skipped" do
      user = generate(user())
      entry = digest(default: false)
      refute Notifications.should_deliver?(user, :weekly_digest, entry)
    end

    test "digest sends when the user has opted in" do
      user = generate_user_with_prefs(%{"weekly_digest" => true})
      entry = digest(default: false)
      assert Notifications.should_deliver?(user, :weekly_digest, entry)
    end

    test "garbage value in the preferences map falls back to the default" do
      user = generate_user_with_prefs(%{"rsvp_received" => "yes"})
      entry = activity(default: true)
      assert Notifications.should_deliver?(user, :rsvp_received, entry)
    end

    test "unconfirmed users still receive transactional security emails" do
      user = generate(user(confirmed_at: nil))
      entry = transactional()
      assert Notifications.should_deliver?(user, :password_changed, entry)
    end

    test "unconfirmed users skip activity and digest categories" do
      user = generate(user(confirmed_at: nil))
      refute Notifications.should_deliver?(user, :rsvp_received, activity(default: true))
      refute Notifications.should_deliver?(user, :weekly_digest, digest(default: false))
    end

    test "non-User input returns false" do
      refute Notifications.should_deliver?(nil, :anything, transactional())
      refute Notifications.should_deliver?(%{not_a: "user"}, :anything, transactional())
    end
  end

  defp transactional, do: %{category: :transactional, default: true}
  defp activity(default: default), do: %{category: :activity, default: default}
  defp digest(default: default), do: %{category: :digest, default: default}

  defp generate_user_with_prefs(prefs) do
    user = generate(user())

    {:ok, updated} =
      user
      |> Ash.Changeset.for_update(
        :update_notification_preferences,
        %{preferences: prefs},
        actor: user
      )
      |> Ash.update()

    %User{} = updated
  end
end

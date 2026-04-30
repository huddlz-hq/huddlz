defmodule Huddlz.Notifications.UnsubscribeTokenTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications

  describe "unsubscribe_token/2 + verify_unsubscribe_token/1" do
    test "round-trips a valid token back to the same user_id and trigger" do
      user = generate(user())
      token = Notifications.unsubscribe_token(user, :rsvp_received)
      assert {:ok, {user_id, :rsvp_received}} = Notifications.verify_unsubscribe_token(token)
      assert user_id == user.id
    end

    test "rejects a tampered token" do
      user = generate(user())
      token = Notifications.unsubscribe_token(user, :rsvp_received)
      # Inject a clearly-out-of-alphabet byte in the middle so the signature
      # can never match, regardless of the original token's last character.
      tampered = String.slice(token, 0, 5) <> "!!!" <> String.slice(token, 5..-1//1)
      assert {:error, _reason} = Notifications.verify_unsubscribe_token(tampered)
    end

    test "rejects an expired token via max_age" do
      user = generate(user())
      old_token = sign_with_age(user, :rsvp_received, _signed_at_ms = 0)
      assert {:error, :expired} = Notifications.verify_unsubscribe_token(old_token)
    end

    test "rejects garbage" do
      assert {:error, _} = Notifications.verify_unsubscribe_token("not-a-token")
    end
  end

  defp sign_with_age(user, trigger, signed_at_ms) do
    Phoenix.Token.sign(
      HuddlzWeb.Endpoint,
      "notifications:unsubscribe",
      {user.id, trigger},
      signed_at: signed_at_ms
    )
  end
end

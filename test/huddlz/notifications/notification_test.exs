defmodule Huddlz.Notifications.NotificationTest do
  use Huddlz.DataCase, async: false

  alias Huddlz.Notifications
  alias Huddlz.Notifications.Notification

  describe "deliver/3 persists an in-app Notification" do
    test "creates a row with summary fields populated from the trigger payload" do
      user = generate(user(confirmed_at: DateTime.utc_now()))

      {:ok, _job} =
        Notifications.deliver(user, :rsvp_confirmation, %{
          "huddl_id" => "00000000-0000-0000-0000-000000000000",
          "huddl_title" => "Boat Drinks",
          "group_slug" => "phoenix-elixir-meetup",
          "starts_at_iso" => "2026-05-09T18:00:00Z"
        })

      {:ok, %{results: [notification]}} =
        Notifications.list_for_user(actor: user, page: [limit: 5])

      assert notification.title == "RSVP confirmed: Boat Drinks"
      assert notification.description == "Starts May 09, 2026"

      assert notification.source_url ==
               "/groups/phoenix-elixir-meetup/huddlz/00000000-0000-0000-0000-000000000000"

      assert is_nil(notification.read_at)
    end
  end

  describe "list_for_user :for_user" do
    test "only returns the actor's notifications" do
      user_a = generate(user(confirmed_at: DateTime.utc_now()))
      user_b = generate(user(confirmed_at: DateTime.utc_now()))

      Notifications.deliver(user_a, :password_changed, %{})
      Notifications.deliver(user_b, :password_changed, %{})

      {:ok, %{results: a_results}} = Notifications.list_for_user(actor: user_a, page: [limit: 10])
      {:ok, %{results: b_results}} = Notifications.list_for_user(actor: user_b, page: [limit: 10])

      assert length(a_results) == 1
      assert length(b_results) == 1
      assert hd(a_results).user_id == user_a.id
      assert hd(b_results).user_id == user_b.id
    end

    test "sorts newest first" do
      user = generate(user(confirmed_at: DateTime.utc_now()))

      Notifications.deliver(user, :password_changed, %{})
      Notifications.deliver(user, :email_changed, %{"old_email" => "a@b.com"})

      {:ok, %{results: results}} = Notifications.list_for_user(actor: user, page: [limit: 10])

      assert [first, second] = results
      assert DateTime.compare(first.inserted_at, second.inserted_at) in [:gt, :eq]
    end
  end

  describe "mark_read" do
    test "stamps read_at when the actor owns the notification" do
      user = generate(user(confirmed_at: DateTime.utc_now()))

      Notifications.deliver(user, :password_changed, %{})

      {:ok, %{results: [notification]}} =
        Notifications.list_for_user(actor: user, page: [limit: 5])

      assert is_nil(notification.read_at)

      {:ok, updated} = Notifications.mark_read(notification, actor: user)
      refute is_nil(updated.read_at)
    end

    test "is a no-op on an already-read notification" do
      user = generate(user(confirmed_at: DateTime.utc_now()))
      Notifications.deliver(user, :password_changed, %{})

      {:ok, %{results: [notification]}} =
        Notifications.list_for_user(actor: user, page: [limit: 5])

      {:ok, first} = Notifications.mark_read(notification, actor: user)
      {:ok, second} = Notifications.mark_read(first, actor: user)

      assert first.read_at == second.read_at
    end

    test "rejects updates from a non-owning actor" do
      owner = generate(user(confirmed_at: DateTime.utc_now()))
      stranger = generate(user(confirmed_at: DateTime.utc_now()))

      Notifications.deliver(owner, :password_changed, %{})

      {:ok, %{results: [notification]}} =
        Notifications.list_for_user(actor: owner, page: [limit: 5])

      assert {:error, _} = Notifications.mark_read(notification, actor: stranger)
    end
  end

  describe "mark_unread" do
    test "clears the read marker" do
      user = generate(user(confirmed_at: DateTime.utc_now()))
      Notifications.deliver(user, :password_changed, %{})

      {:ok, %{results: [notification]}} =
        Notifications.list_for_user(actor: user, page: [limit: 5])

      {:ok, read} = Notifications.mark_read(notification, actor: user)
      refute is_nil(read.read_at)

      {:ok, unread} = Notifications.mark_unread(read, actor: user)
      assert is_nil(unread.read_at)
    end
  end

  describe "create authorization" do
    test "system path with authorize?: false succeeds" do
      user = generate(user(confirmed_at: DateTime.utc_now()))

      assert {:ok, _} =
               Notification
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   user_id: user.id,
                   trigger: "password_changed",
                   payload: %{},
                   title: "Password changed"
                 },
                 authorize?: false
               )
               |> Ash.create()
    end
  end
end

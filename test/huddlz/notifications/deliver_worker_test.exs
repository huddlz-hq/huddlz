defmodule Huddlz.Notifications.DeliverWorkerTest do
  use Huddlz.DataCase, async: true
  use Oban.Testing, repo: Huddlz.Repo
  import Swoosh.TestAssertions

  alias Huddlz.Notifications
  alias Huddlz.Notifications.DeliverWorker

  describe "deliver_async/3" do
    test "enqueues a job in the :notifications queue with string-keyed args" do
      user = generate(user(confirmed_at: DateTime.utc_now()))

      assert {:ok, _job} = Notifications.deliver_async(user, :password_changed)

      assert_enqueued(
        worker: DeliverWorker,
        queue: :notifications,
        args: %{
          "user_id" => user.id,
          "trigger" => "password_changed",
          "payload" => %{}
        }
      )
    end

    test "raises on unknown triggers up front rather than after enqueue" do
      user = generate(user())

      assert_raise KeyError, fn ->
        Notifications.deliver_async(user, :totally_made_up)
      end

      refute_enqueued(worker: DeliverWorker)
    end
  end

  describe "perform/1" do
    test "delivers the email via the live sender for a known trigger" do
      user = generate(user(confirmed_at: DateTime.utc_now()))

      assert :ok =
               perform_job(DeliverWorker, %{
                 "user_id" => user.id,
                 "trigger" => "password_changed",
                 "payload" => %{}
               })

      assert_email_sent(fn email ->
        email.subject == "Your huddlz password was changed" and
          email.to == [{"", to_string(user.email)}]
      end)
    end

    test "succeeds without sending when the user has opted out" do
      user = generate(user(confirmed_at: DateTime.utc_now()))

      user
      |> Ash.Changeset.for_update(
        :update_notification_preferences,
        %{preferences: %{"rsvp_received" => false}},
        actor: user
      )
      |> Ash.update!()

      assert :ok =
               perform_job(DeliverWorker, %{
                 "user_id" => user.id,
                 "trigger" => "rsvp_received",
                 "payload" => %{}
               })

      refute_email_sent()
    end

    test "cancels the job when the user no longer exists" do
      assert {:cancel, "user " <> _} =
               perform_job(DeliverWorker, %{
                 "user_id" => Ecto.UUID.generate(),
                 "trigger" => "password_changed",
                 "payload" => %{}
               })

      refute_email_sent()
    end

    test "cancels the job when the trigger atom is unknown" do
      assert {:cancel, "unknown trigger"} =
               perform_job(DeliverWorker, %{
                 "user_id" => Ecto.UUID.generate(),
                 "trigger" => "trigger_that_does_not_exist_anywhere",
                 "payload" => %{}
               })

      refute_email_sent()
    end
  end
end

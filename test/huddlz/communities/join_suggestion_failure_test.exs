defmodule Huddlz.Communities.JoinSuggestionFailureTest do
  use Huddlz.DataCase, async: false
  use Oban.Testing, repo: Huddlz.Repo

  @moduletag :join_suggestion_failure

  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Notifications
  alias Huddlz.Notifications.DeliverWorker

  defmodule FailingQueue do
    @behaviour Huddlz.Notifications.Queue

    @impl true
    def enqueue(_args), do: {:error, :queue_unavailable}
  end

  test "a queue outage preserves the suggestion for a later successful attempt" do
    queue = Application.fetch_env!(:huddlz, :notification_queue)
    on_exit(fn -> Application.put_env(:huddlz, :notification_queue, queue) end)

    owner = generate(user(role: :user))
    person = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: owner.id,
          is_private: false,
          lifecycle_state: :completed
        )
      )

    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: person.id})
    |> Ash.create!(authorize?: false)

    huddl = Ash.Seed.update!(huddl, %{completed_at: DateTime.add(DateTime.utc_now(), -25, :hour)})
    Application.put_env(:huddlz, :notification_queue, FailingQueue)

    assert {:error, _reason} = Communities.suggest_joining(huddl, authorize?: false)
    assert [due] = Communities.huddlz_due_for_join_suggestions!(authorize?: false)
    assert due.id == huddl.id
    assert [] = Notifications.list_for_user!(actor: person)

    Application.put_env(:huddlz, :notification_queue, queue)
    Communities.suggest_joining!(due, authorize?: false)

    assert [suggestion] =
             Enum.filter(
               all_enqueued(worker: DeliverWorker),
               &(&1.args["trigger"] == "group_join_suggestion")
             )

    assert suggestion.args["user_id"] == person.id
    assert [%{trigger: "group_join_suggestion"}] = Notifications.list_for_user!(actor: person)
    assert [] = Communities.huddlz_due_for_join_suggestions!(authorize?: false)
  end
end

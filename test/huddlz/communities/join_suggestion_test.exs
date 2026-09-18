defmodule Huddlz.Communities.JoinSuggestionTest do
  @moduledoc """
  The rules behind the join suggestion that the outer scenarios in
  `test/features/drop_in_emails.feature` cannot reach: what "once per group"
  means when two huddlz come due together, and who is never considered.
  """

  use Huddlz.DataCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Notifications
  alias Huddlz.Notifications.DeliverWorker

  setup do
    owner = generate(user(role: :user))
    person = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
    %{owner: owner, person: person, group: group}
  end

  defp completed_with_rsvp(%{group: group, owner: owner, person: person}, attrs \\ []) do
    huddl =
      generate(
        past_huddl(
          [
            group_id: group.id,
            creator_id: owner.id,
            is_private: false,
            lifecycle_state: :completed
          ] ++ attrs
        )
      )

    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: person.id})
    |> Ash.create!(authorize?: false)

    Ash.Seed.update!(huddl, %{completed_at: DateTime.add(DateTime.utc_now(), -25, :hour)})
  end

  defp suggestions_for(person) do
    all_enqueued(worker: DeliverWorker)
    |> Enum.filter(
      &(&1.args["user_id"] == person.id and &1.args["trigger"] == "group_join_suggestion")
    )
  end

  describe "due_for_join_suggestions" do
    test "is a completed huddl a day on, once", context do
      due = completed_with_rsvp(context)
      fresh = completed_with_rsvp(context)
      Ash.Seed.update!(fresh, %{completed_at: DateTime.utc_now()})

      assert [found] = Communities.huddlz_due_for_join_suggestions!(authorize?: false)
      assert found.id == due.id

      Communities.suggest_joining!(due, authorize?: false)
      assert [] = Communities.huddlz_due_for_join_suggestions!(authorize?: false)
    end
  end

  describe "suggest_joining" do
    test "two huddlz of one group coming due together suggest once",
         %{person: person} = context do
      first = completed_with_rsvp(context)
      second = completed_with_rsvp(context)

      Communities.suggest_joining!(first, authorize?: false)
      Communities.suggest_joining!(second, authorize?: false)

      assert [_one] = suggestions_for(person)
      assert {:ok, %{total_count: 1}} = notifications(person)
    end

    test "records the suggestion on the person's reminder for the group",
         %{person: person, group: group} = context do
      context |> completed_with_rsvp() |> Communities.suggest_joining!(authorize?: false)

      assert {:ok, %{emailed_at: %DateTime{}, suppressed?: false}} =
               Communities.get_drop_in_reminder(group.id, actor: person)
    end

    test "a suspended person is passed over and keeps their one suggestion",
         %{person: person, group: group} = context do
      huddl = completed_with_rsvp(context)
      Ash.Seed.update!(person, %{suspended_at: DateTime.utc_now()})

      Communities.suggest_joining!(huddl, authorize?: false)

      assert [] = suggestions_for(person)

      assert {:ok, nil} =
               Communities.get_drop_in_reminder(group.id, actor: person, not_found_error?: false)
    end

    test "a private group's drop-ins are not suggested to", %{person: person} = context do
      huddl = completed_with_rsvp(context)
      Ash.Seed.update!(context.group, %{is_public: false})

      Communities.suggest_joining!(huddl, authorize?: false)

      assert [] = suggestions_for(person)
    end

    test "an archived group's drop-ins are not suggested to",
         %{person: person, owner: owner} = context do
      huddl = completed_with_rsvp(context)
      Communities.archive_group!(context.group, actor: owner)

      Communities.suggest_joining!(huddl, authorize?: false)

      assert [] = suggestions_for(person)
    end
  end

  describe "mark_emailed" do
    test "never reopens a dismissed reminder", %{person: person, group: group} do
      Communities.dismiss_join_suggestion!(group.id, actor: person)

      assert {:error, _stale} =
               Communities.mark_join_suggestion_emailed(
                 %{group_id: group.id, user_id: person.id},
                 authorize?: false
               )
    end

    test "is refused to any actor", %{person: person, group: group} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Communities.mark_join_suggestion_emailed(
                 %{group_id: group.id, user_id: person.id},
                 actor: person
               )
    end
  end

  defp notifications(person) do
    Notifications.list_for_user(actor: person, page: [count: true])
    |> case do
      {:ok, page} ->
        {:ok, %{total_count: Enum.count(page.results, &(&1.trigger == "group_join_suggestion"))}}

      error ->
        error
    end
  end
end

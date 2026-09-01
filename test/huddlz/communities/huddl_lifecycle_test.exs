defmodule Huddlz.Communities.HuddlLifecycleTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator

  alias Ecto.Adapters.SQL.Sandbox
  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Notifications.Notification

  require Ash.Query

  setup do
    owner = generate(user(role: :user))
    member = generate(user(role: :user))

    {group, _memberships} =
      generate_group_with_members(
        owner: owner,
        group: [is_public: true],
        members: [%{user: member, role: :member}]
      )

    %{owner: owner, member: member, group: group}
  end

  @tag :huddl_lifecycle
  test "a draft is private to organizers and excluded from discovery", context do
    draft = create_draft(context)

    assert draft.lifecycle_state == :draft
    assert draft.published_at == nil
    assert draft.published_by_id == nil
    assert {:error, _error} = Communities.get_huddl(draft.id, actor: context.member)
    assert {:error, _error} = Communities.get_huddl(draft.id)

    assert Communities.get_huddl!(draft.id, actor: context.owner).id == draft.id

    assert [] =
             Communities.search_huddlz!(
               nil,
               :all,
               nil,
               nil,
               nil,
               nil,
               nil,
               :soonest,
               actor: context.owner,
               page: false
             )
  end

  @tag :huddl_lifecycle
  test "publishing is explicit, authorized, and idempotent", context do
    draft = create_draft(context)

    assert notification_count(context.member.id, "huddl_new") == 0

    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.publish_huddl(draft, actor: context.member)

    assert {:ok, published} = Communities.publish_huddl(draft, actor: context.owner)
    assert published.lifecycle_state == :published
    assert %DateTime{} = published.published_at
    assert published.published_by_id == context.owner.id

    assert {:ok, _same_state} = Communities.publish_huddl(published, actor: context.owner)
    assert notification_count(context.member.id, "huddl_new") == 1
  end

  @tag :huddl_lifecycle
  test "cancelling preserves the huddl and RSVP history and is idempotent", context do
    huddl = generate(huddl(group_id: context.group.id, creator_id: context.owner.id))

    Communities.rsvp_huddl!(huddl, actor: context.member)

    assert {:ok, cancelled} =
             Communities.cancel_huddl(huddl, "Venue lost power", actor: context.owner)

    assert cancelled.lifecycle_state == :cancelled
    assert cancelled.cancellation_reason == "Venue lost power"
    assert %DateTime{} = cancelled.cancelled_at
    assert cancelled.cancelled_by_id == context.owner.id
    assert Communities.get_huddl!(cancelled.id, actor: context.member).id == cancelled.id

    assert 2 ==
             HuddlAttendee
             |> Ash.Query.filter(huddl_id == ^huddl.id)
             |> Ash.count!(authorize?: false)

    assert {:ok, _same_state} =
             Communities.cancel_huddl(cancelled, "A duplicate submission", actor: context.owner)

    assert notification_count(context.member.id, "huddl_cancelled") == 1
  end

  @tag :huddl_lifecycle
  test "invalid lifecycle transitions return handled errors", context do
    draft = create_draft(context)

    assert {:error, %Ash.Error.Invalid{}} =
             Communities.cancel_huddl(draft, nil, actor: context.owner)

    published = generate(huddl(group_id: context.group.id, creator_id: context.owner.id))
    cancelled = Communities.cancel_huddl!(published, nil, actor: context.owner)

    assert {:error, %Ash.Error.Invalid{}} =
             Communities.publish_huddl(cancelled, actor: context.owner)

    assert {:error, %Ash.Error.Invalid{}} =
             Communities.complete_huddl(published, authorize?: false)
  end

  @tag :huddl_lifecycle
  test "an ended huddl cannot be cancelled while completion is pending", context do
    now = DateTime.utc_now()

    ended =
      Ash.Seed.seed!(Huddl, %{
        title: "Already Ended",
        description: "Waiting for scheduled completion",
        starts_at: DateTime.add(now, -2, :hour),
        ends_at: DateTime.add(now, -1, :hour),
        time_zone: "Etc/UTC",
        event_type: :virtual,
        virtual_link: "https://example.com/ended",
        is_private: false,
        group_id: context.group.id,
        creator_id: context.owner.id,
        lifecycle_state: :published,
        published_at: DateTime.add(now, -3, :hour),
        published_by_id: context.owner.id
      })

    assert {:error, %Ash.Error.Invalid{}} =
             Communities.cancel_huddl(ended, nil, actor: context.owner)
  end

  @tag :requires_huddl_template
  test "publishing a recurring draft leaves sibling drafts unpublished", context do
    template =
      HuddlTemplate
      |> Ash.Changeset.for_create(:create, %{
        frequency: :weekly,
        repeat_until: Date.add(Date.utc_today(), 30)
      })
      |> Ash.create!(authorize?: false)

    source =
      generate(
        huddl(
          group_id: context.group.id,
          creator_id: context.owner.id,
          huddl_template_id: template.id,
          lifecycle_state: :draft,
          date: Date.add(Date.utc_today(), 2)
        )
      )

    future =
      generate(
        huddl(
          group_id: context.group.id,
          creator_id: context.owner.id,
          huddl_template_id: template.id,
          lifecycle_state: :draft,
          date: Date.add(Date.utc_today(), 9)
        )
      )

    assert {:ok, _published} = Communities.publish_huddl(source, actor: context.owner)
    assert Communities.get_huddl!(future.id, actor: context.owner).lifecycle_state == :draft
    assert notification_count(context.member.id, "huddl_new") == 1
  end

  @tag :huddl_lifecycle
  test "published and cancelled huddlz cannot be hard-deleted", context do
    published = generate(huddl(group_id: context.group.id, creator_id: context.owner.id))

    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.destroy_huddl(published, actor: context.owner)

    cancelled = Communities.cancel_huddl!(published, nil, actor: context.owner)

    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.destroy_huddl(cancelled, actor: context.owner)

    draft = create_draft(context)
    assert :ok = Communities.destroy_huddl(draft, actor: context.owner)
  end

  @tag :huddl_lifecycle
  test "completion is persisted and idempotent after a published huddl ends", context do
    now = DateTime.utc_now()

    ended =
      Ash.Seed.seed!(Huddl, %{
        title: "Already Ended",
        description: "Ready for lifecycle completion",
        starts_at: DateTime.add(now, -2, :hour),
        ends_at: DateTime.add(now, -1, :hour),
        time_zone: "Etc/UTC",
        event_type: :virtual,
        virtual_link: "https://example.com/ended",
        is_private: false,
        group_id: context.group.id,
        creator_id: context.owner.id,
        lifecycle_state: :published,
        published_at: DateTime.add(now, -3, :hour),
        published_by_id: context.owner.id
      })

    assert {:ok, completed} = Communities.complete_huddl(ended, authorize?: false)
    assert completed.lifecycle_state == :completed
    assert %DateTime{} = completed.completed_at

    assert {:ok, repeated} = Communities.complete_huddl(completed, authorize?: false)
    assert repeated.completed_at == completed.completed_at
  end

  @tag :huddl_lifecycle
  test "concurrent publication attempts transition and notify once", context do
    draft = create_draft(context)
    test_process = self()

    tasks =
      Enum.map(1..2, fn _attempt ->
        Task.async(fn ->
          send(test_process, {:publish_ready, self()})

          receive do
            :publish -> Communities.publish_huddl(draft, actor: context.owner)
          end
        end)
      end)

    Enum.each(tasks, fn task ->
      Sandbox.allow(Huddlz.Repo, test_process, task.pid)
      task_pid = task.pid
      assert_receive {:publish_ready, ^task_pid}
    end)

    Enum.each(tasks, &send(&1.pid, :publish))

    assert tasks
           |> Task.await_many()
           |> Enum.all?(&match?({:ok, %{lifecycle_state: :published}}, &1))

    assert notification_count(context.member.id, "huddl_new") == 1
  end

  defp create_draft(context) do
    generate(
      huddl(
        group_id: context.group.id,
        creator_id: context.owner.id,
        lifecycle_state: :draft
      )
    )
  end

  defp notification_count(user_id, trigger) do
    Notification
    |> Ash.Query.filter(user_id == ^user_id and trigger == ^trigger)
    |> Ash.count!(authorize?: false)
  end
end

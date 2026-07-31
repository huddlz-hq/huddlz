defmodule Huddlz.Communities.HuddlLifecycleNotificationFailureTest do
  use Huddlz.DataCase, async: false

  import Huddlz.Generator

  alias Huddlz.Communities

  defmodule FailingNotificationQueue do
    @behaviour Huddlz.Notifications.Queue

    @impl true
    def enqueue(_args), do: {:error, :queue_unavailable}
  end

  setup do
    previous_queue = Application.get_env(:huddlz, :notification_queue)

    on_exit(fn ->
      Application.put_env(:huddlz, :notification_queue, previous_queue)
    end)

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
  test "publication rolls back when member notifications cannot be queued", context do
    draft =
      generate(
        huddl(
          group_id: context.group.id,
          creator_id: context.owner.id,
          lifecycle_state: :draft
        )
      )

    Application.put_env(:huddlz, :notification_queue, FailingNotificationQueue)

    assert {:error, _error} = Communities.publish_huddl(draft, actor: context.owner)

    reloaded = Communities.get_huddl!(draft.id, actor: context.owner)
    assert reloaded.lifecycle_state == :draft
    assert reloaded.published_at == nil
  end

  @tag :huddl_lifecycle
  test "cancellation rolls back when attendee notifications cannot be queued", context do
    published =
      generate(
        huddl(
          group_id: context.group.id,
          creator_id: context.owner.id,
          actor: context.owner
        )
      )

    Communities.rsvp_huddl!(published, actor: context.member)
    Application.put_env(:huddlz, :notification_queue, FailingNotificationQueue)

    assert {:error, _error} =
             Communities.cancel_huddl(published, "Queue is down", actor: context.owner)

    reloaded = Communities.get_huddl!(published.id, actor: context.owner)
    assert reloaded.lifecycle_state == :published
    assert reloaded.cancelled_at == nil
    assert reloaded.cancellation_reason == nil
  end
end

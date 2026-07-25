defmodule Huddlz.Communities.HuddlLifecycleTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator

  alias Huddlz.Communities
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

    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.publish_huddl(draft, actor: context.member)

    assert {:ok, published} = Communities.publish_huddl(draft, actor: context.owner)
    assert published.lifecycle_state == :published
    assert %DateTime{} = published.published_at

    assert {:ok, _same_state} = Communities.publish_huddl(published, actor: context.owner)

    assert 1 ==
             Notification
             |> Ash.Query.filter(user_id == ^context.member.id and trigger == "huddl_new")
             |> Ash.count!(authorize?: false)
  end

  @tag :huddl_lifecycle
  test "cancelling preserves the huddl and RSVP history and is idempotent", context do
    huddl = generate(huddl(group_id: context.group.id, creator_id: context.owner.id))

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: context.member)
    |> Ash.update!()

    assert {:ok, cancelled} =
             Communities.cancel_huddl(huddl, "Venue lost power", actor: context.owner)

    assert cancelled.lifecycle_state == :cancelled
    assert cancelled.cancellation_reason == "Venue lost power"
    assert %DateTime{} = cancelled.cancelled_at
    assert Communities.get_huddl!(cancelled.id, actor: context.member).id == cancelled.id

    assert 2 ==
             HuddlAttendee
             |> Ash.Query.filter(huddl_id == ^huddl.id)
             |> Ash.count!(authorize?: false)

    assert {:ok, _same_state} =
             Communities.cancel_huddl(cancelled, "A duplicate submission", actor: context.owner)

    assert 1 ==
             Notification
             |> Ash.Query.filter(user_id == ^context.member.id and trigger == "huddl_cancelled")
             |> Ash.count!(authorize?: false)
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
  end

  @tag :requires_huddl_template
  test "publishing a recurring draft publishes generated dates with one announcement", context do
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
    assert Communities.get_huddl!(future.id, actor: context.owner).lifecycle_state == :published

    assert 1 ==
             Notification
             |> Ash.Query.filter(user_id == ^context.member.id and trigger == "huddl_new")
             |> Ash.count!(authorize?: false)
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
end

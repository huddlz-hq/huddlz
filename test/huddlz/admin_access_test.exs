defmodule Huddlz.AdminAccessTest do
  use Huddlz.DataCase, async: false
  @moduletag :admin_access
  require Ash.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupImage
  alias Huddlz.Communities.GroupLocation
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlCoverImage

  setup do
    admin = generate(user(role: :admin))
    owner = generate(user())
    group = generate(group(actor: owner, is_public: false))

    huddl =
      generate(huddl(group_id: group.id, actor: owner, date: Date.add(Date.utc_today(), 1)))

    %{admin: admin, owner: owner, group: group, huddl: huddl}
  end

  test "private groups and their huddlz follow membership rather than platform role", ctx do
    for resource <- [Group, Huddl, GroupLocation] do
      assert [] == Ash.read!(resource, actor: ctx.admin)
    end

    Communities.add_member!(ctx.group.id, ctx.admin.id, :member, actor: ctx.owner)
    assert Enum.any?(Ash.read!(Group, actor: ctx.admin), &(&1.id == ctx.group.id))
    assert Enum.any?(Ash.read!(Huddl, actor: ctx.admin), &(&1.id == ctx.huddl.id))

    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.update_huddl(ctx.huddl, %{title: "Forbidden"}, actor: ctx.admin)
  end

  test "private media is hidden from nonmembers including administrators", ctx do
    attrs = %{
      filename: "private.jpg",
      content_type: "image/jpeg",
      size_bytes: 1000,
      storage_path: "/uploads/private-#{Ash.UUID.generate()}.jpg"
    }

    group_image =
      Communities.create_group_image!(Map.put(attrs, :group_id, ctx.group.id), actor: ctx.owner)

    cover =
      Communities.create_huddl_cover_image!(Map.put(attrs, :huddl_id, ctx.huddl.id),
        actor: ctx.owner
      )

    for {resource, record} <- [{GroupImage, group_image}, {HuddlCoverImage, cover}] do
      assert [] == resource |> Ash.Query.filter(id == ^record.id) |> Ash.read!(actor: ctx.admin)
      assert [_] = resource |> Ash.Query.filter(id == ^record.id) |> Ash.read!(actor: ctx.owner)
    end
  end

  test "platform overview cannot reveal private group or huddl content", ctx do
    stats = Huddlz.Admin.platform_overview!("90d", actor: ctx.admin)
    refute Enum.any?(stats.active_groups.groups, &(&1.id == ctx.group.id))
    refute Enum.any?(stats.coming_up.next, &(&1.id == ctx.huddl.id))
    assert stats.groups.count == 0

    membership = Communities.add_member!(ctx.group.id, ctx.admin.id, :member, actor: ctx.owner)
    assert Huddlz.Admin.platform_overview!("90d", actor: ctx.admin).groups.count == 0

    Ash.update!(membership, %{role: :organizer}, action: :change_role, actor: ctx.owner)
    stats = Huddlz.Admin.platform_overview!("90d", actor: ctx.admin)
    assert stats.groups.count == 1
    assert Enum.any?(stats.coming_up.next, &(&1.id == ctx.huddl.id))
  end

  test "account review and account counts require staff and respect community permissions", ctx do
    assert {:error, %Ash.Error.Forbidden{}} =
             Huddlz.Admin.review_account(ctx.owner.id, actor: ctx.owner)

    assert {:error, %Ash.Error.Forbidden{}} =
             Huddlz.Accounts.count_users_by_email("", false, actor: ctx.owner)

    review = Huddlz.Admin.review_account!(ctx.owner.id, actor: ctx.admin)
    assert review.user.id == ctx.owner.id
    assert review.groups == []
    assert review.huddlz == []

    Communities.add_member!(ctx.group.id, ctx.admin.id, :organizer, actor: ctx.owner)
    review = Huddlz.Admin.review_account!(ctx.owner.id, actor: ctx.admin)
    assert Enum.map(review.groups, & &1.id) == [ctx.group.id]
    assert Enum.map(review.huddlz, & &1.id) == [ctx.huddl.id]
  end

  test "administrators retain personal actions and their own group permissions", ctx do
    group = generate(group(actor: ctx.admin, is_public: false))
    huddl = generate(huddl(group_id: group.id, actor: ctx.admin))
    updated = Communities.update_huddl!(huddl, %{title: "My huddl"}, actor: ctx.admin)
    assert updated.title == "My huddl"

    updated_group =
      Ash.update!(group, %{name: "My group"}, action: :update_details, actor: ctx.admin)

    assert to_string(updated_group.name) == "My group"

    updated_user =
      Ash.update!(ctx.admin, %{theme_preference: :dark},
        action: :update_theme_preference,
        actor: ctx.admin
      )

    assert updated_user.theme_preference == :dark
  end

  test "session attribution survives atomic personal changes and nested huddl changes", ctx do
    record = Huddlz.Admin.start_impersonation!(ctx.owner.id, actor: ctx.admin)
    actor = Ash.Resource.put_metadata(ctx.owner, :impersonation, record)
    Ash.update!(actor, %{theme_preference: :dark}, action: :update_theme_preference, actor: actor)
    Communities.update_huddl!(ctx.huddl, %{title: "Troubleshooting"}, actor: actor)

    for resource <- [Huddlz.Accounts.User.Version, Huddl.Version] do
      row =
        resource
        |> Ash.Query.filter(impersonation_id == ^record.id)
        |> Ash.read_one!(authorize?: false)

      assert row.actor_id == ctx.owner.id
      assert row.impersonator_id == ctx.admin.id
    end
  end
end

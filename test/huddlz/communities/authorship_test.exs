defmodule Huddlz.Communities.AuthorshipTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities

  test "group creation accepts the actor at execution time" do
    owner = generate(user())

    changeset =
      Ash.Changeset.for_create(Communities.Group, :create_group, %{
        name: "Late actor group",
        description: "A group with an actor supplied when the action runs",
        location: "Austin, TX",
        time_zone: "America/Chicago",
        is_public: true
      })

    assert {:ok, group} = Ash.create(changeset, actor: owner)
    assert group.owner_id == owner.id
    assert Communities.get_group_member!(group.id, owner.id, actor: owner).role == :owner
  end

  test "huddl creation accepts the actor at execution time" do
    owner = generate(user())
    group = generate(group(actor: owner))
    starts_at = DateTime.add(DateTime.utc_now(), 1, :day)

    changeset =
      Ash.Changeset.for_create(Communities.Huddl, :create, %{
        title: "Late actor huddl",
        group_id: group.id,
        event_type: :virtual,
        virtual_link: "https://example.com/call",
        starts_at: starts_at,
        ends_at: DateTime.add(starts_at, 1, :hour)
      })

    assert {:ok, huddl} = Ash.create(changeset, actor: owner)
    assert huddl.creator_id == owner.id
  end

  test "group creation attributes ownership to its actor and rejects a supplied owner" do
    owner = generate(user())
    outsider = generate(user())

    assert {:ok, group} =
             Communities.create_group(
               "Authored group",
               "A group created by its owner",
               "Austin, TX",
               "America/Chicago",
               true,
               actor: owner
             )

    assert group.owner_id == owner.id
    assert Communities.get_group_member!(group.id, owner.id, actor: owner).role == :owner

    assert {:error, %Ash.Error.Invalid{}} =
             Communities.create_group(
               "Spoofed group",
               "An attempt to supply another owner",
               "Austin, TX",
               "America/Chicago",
               true,
               %{owner_id: outsider.id},
               actor: owner
             )
  end

  test "huddl creation attributes authorship to its actor and rejects a supplied creator" do
    owner = generate(user())
    outsider = generate(user())
    group = generate(group(actor: owner))
    starts_at = DateTime.add(DateTime.utc_now(), 1, :day)

    attrs = %{
      title: "Authored huddl",
      group_id: group.id,
      event_type: :virtual,
      virtual_link: "https://example.com/call",
      starts_at: starts_at,
      ends_at: DateTime.add(starts_at, 1, :hour)
    }

    assert {:ok, huddl} = Communities.create_huddl(attrs, actor: owner)
    assert huddl.creator_id == owner.id

    assert {:error, %Ash.Error.Invalid{}} =
             Communities.create_huddl(Map.put(attrs, :creator_id, outsider.id), actor: owner)
  end
end

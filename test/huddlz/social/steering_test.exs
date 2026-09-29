defmodule Huddlz.Social.SteeringTest do
  # Stubs the platforms' webhooks through Req.Test, owned by this process.
  use Huddlz.DataCase, async: true

  require Ash.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.SocialPost

  setup do
    test = self()

    Req.Test.stub(Huddlz.Social, fn conn ->
      send(test, {:social_post, conn.body_params["text"]})
      Req.Test.json(conn, %{"ok" => true})
    end)

    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    connection =
      generate(
        social_connection(
          group_id: group.id,
          moments: [:week_before, :morning_of],
          actor: owner
        )
      )

    huddl = upcoming_huddl(group, owner)

    %{owner: owner, group: group, connection: connection, huddl: huddl}
  end

  describe "skipping" do
    test "drops the huddl's planned posts there, follow-ups included", %{
      owner: owner,
      connection: connection,
      huddl: huddl
    } do
      Ash.Seed.seed!(SocialPost, %{
        social_connection_id: connection.id,
        huddl_id: huddl.id,
        occasion: :moved,
        due_at: DateTime.add(DateTime.utc_now(), 60, :second) |> DateTime.truncate(:second)
      })

      Communities.skip_social_connection!(huddl, connection.id, actor: owner)

      assert posts(huddl) == []
    end

    test "keeps it off when the connection's schedule changes or it resumes", %{
      owner: owner,
      connection: connection,
      huddl: huddl
    } do
      Communities.skip_social_connection!(huddl, connection.id, actor: owner)

      connection
      |> Communities.edit_social_connection!(%{moments: [:day_before]}, actor: owner)
      |> Communities.pause_social_connection!(actor: owner)
      |> Communities.resume_social_connection!(actor: owner)

      assert posts(huddl) == []
    end

    test "keeps it off when the huddl is edited", %{
      owner: owner,
      connection: connection,
      huddl: huddl
    } do
      Communities.skip_social_connection!(huddl, connection.id, actor: owner)
      Communities.update_huddl!(huddl, %{title: "Hack night, renamed"}, actor: owner)

      assert posts(huddl) == []
    end

    test "twice changes nothing", %{owner: owner, connection: connection, huddl: huddl} do
      Communities.skip_social_connection!(huddl, connection.id, actor: owner)
      Communities.skip_social_connection!(huddl, connection.id, actor: owner)
      Communities.unskip_social_connection!(huddl, connection.id, actor: owner)

      assert Enum.map(posts(huddl), & &1.occasion) == [:week_before, :morning_of]
    end
  end

  describe "refusals" do
    test "another group's connection", %{owner: owner, huddl: huddl} do
      other = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      elsewhere = generate(social_connection(group_id: other.id, actor: owner))

      assert {:error, error} =
               Communities.skip_social_connection(huddl, elsewhere.id, actor: owner)

      assert Exception.message(error) =~ "is not one of this group's social connections"
    end

    test "a private huddl", %{owner: owner, group: group, connection: connection} do
      huddl = upcoming_huddl(group, owner, is_private: true)

      assert {:error, error} = Communities.post_social_now(huddl, connection.id, actor: owner)
      assert Exception.message(error) =~ "only a published public huddl"
      refute_received {:social_post, _}
    end

    test "a huddl that has started", %{owner: owner, connection: connection, huddl: huddl} do
      huddl = Ash.Seed.update!(huddl, %{starts_at: DateTime.add(DateTime.utc_now(), -60)})

      assert {:error, error} = Communities.post_social_now(huddl, connection.id, actor: owner)
      assert Exception.message(error) =~ "already started"
    end

    test "posting now to a paused connection, or one the huddl is skipped on", %{
      owner: owner,
      connection: connection,
      huddl: huddl
    } do
      Communities.skip_social_connection!(huddl, connection.id, actor: owner)

      assert {:error, error} = Communities.post_social_now(huddl, connection.id, actor: owner)
      assert Exception.message(error) =~ "is skipped for this huddl"

      Communities.unskip_social_connection!(huddl, connection.id, actor: owner)
      Communities.pause_social_connection!(connection, actor: owner)

      assert {:error, error} = Communities.post_social_now(huddl, connection.id, actor: owner)
      assert Exception.message(error) =~ "is not posting right now"
      refute_received {:social_post, _}
    end
  end

  test "posting now twice sends twice", %{owner: owner, connection: connection, huddl: huddl} do
    Communities.post_social_now!(huddl, connection.id, actor: owner)
    Communities.post_social_now!(huddl, connection.id, actor: owner)

    assert_received {:social_post, _}
    assert_received {:social_post, _}
    assert huddl |> posts() |> Enum.count(&(&1.occasion == :now and &1.state == :sent)) == 2
  end

  # The huddl's posts that are planned or went out.
  defp posts(huddl) do
    SocialPost
    |> Ash.Query.filter(huddl_id == ^huddl.id and state in [:scheduled, :sent])
    |> Ash.Query.sort(due_at: :asc, inserted_at: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp upcoming_huddl(group, owner, attrs \\ []) do
    generate(
      huddl(
        [
          group_id: group.id,
          date: Date.add(eastern_today(), 10),
          start_time: ~T[18:00:00],
          duration_minutes: 120,
          actor: owner
        ] ++ attrs
      )
    )
  end
end

defmodule HuddlzWeb.OrganizeLiveSocialTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Huddlz.Communities
  alias Huddlz.Communities.SocialConnection

  setup %{conn: conn} do
    owner = generate(user(role: :user))
    group = generate(group(actor: owner))
    place = generate(social_connection(group_id: group.id, actor: owner))

    {:ok, view, _} =
      live(login(conn, owner), ~p"/organize/#{group.slug}/social?connected=#{place.id}")

    %{owner: owner, group: group, place: place, view: view}
  end

  test "a provider return stays with its original group after another group takes its slug",
       %{owner: owner, group: group, place: place, view: view} do
    # Hold the notification until the old address has a new owner.
    {renamed, notifications} =
      Ash.update!(group, %{slug: "new-address"},
        action: :update_details,
        actor: owner,
        return_notifications?: true
      )

    replacement = generate(group(name: "Another group", slug: group.slug, actor: owner))
    other_place = generate(social_connection(group_id: replacement.id, actor: owner))
    Ash.Notifier.notify(notifications)

    assert_patch(view, ~p"/organize/#{renamed.slug}/social?connected=#{place.id}")
    assert has_element?(view, "#schedule-sheet", "Start posting")
    assert has_element?(view, "#social-connection-#{place.id}")
    refute has_element?(view, "#social-connection-#{other_place.id}")
  end

  test "an obsolete edit selection dismisses removal confirmation", %{view: view, place: place} do
    render_click(element(view, "#remove-connection"))
    assert has_element?(view, "#remove-connection-confirm")
    render_click(view, "edit_connection", %{"id" => Ash.UUID.generate()})
    refute has_element?(view, "#schedule-sheet")
    assert has_element?(view, "#social-connection-#{place.id}")
  end

  for visibility <- [:private, :archived] do
    test "a queued Social interaction respects a group that became #{visibility}", %{
      owner: owner,
      group: group,
      place: place,
      view: view
    } do
      # Hold the change notification so the owner still sees the preceding controls.
      notifications = close_group(group, owner, unquote(visibility))
      render_click(element(view, "#pause-connection-#{place.id}"))
      assert %{state: :posting} = Communities.get_social_connection!(place.id, authorize?: false)

      assert {:error, _} = Communities.resume_social_connection(place, actor: owner)

      assert {:error, _} =
               Communities.edit_social_connection(place, %{opening_line: "Later"}, actor: owner)

      assert {:error, %Ash.Error.Forbidden{}} =
               Communities.send_social_test_post(place.id, actor: owner)

      render_click(element(view, "#remove-connection"))
      render_click(element(view, "#remove-connection-confirm"))
      assert %SocialConnection{} = Communities.get_social_connection!(place.id, authorize?: false)

      Ash.Notifier.notify(notifications)
      refute has_element?(view, "#schedule-sheet")
    end
  end

  test "the owner can still stop and disconnect a private group's old destination", %{
    owner: owner,
    group: group,
    place: place
  } do
    Ash.update!(group, %{is_public: false}, action: :update_details, actor: owner)
    assert {:ok, %{state: :paused}} = Communities.pause_social_connection(place, actor: owner)
    assert :ok = Communities.remove_social_connection(place, actor: owner)
  end

  defp close_group(group, owner, :private) do
    {_group, notifications} =
      Ash.update!(group, %{is_public: false},
        action: :update_details,
        actor: owner,
        return_notifications?: true
      )

    notifications
  end

  defp close_group(group, owner, :archived) do
    {:ok, notifications} =
      Communities.archive_group(group, actor: owner, return_notifications?: true)

    notifications
  end
end

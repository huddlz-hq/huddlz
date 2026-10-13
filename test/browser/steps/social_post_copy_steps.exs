defmodule BrowserSocialPostCopySteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest

  step "I am viewing a public huddl in the organize workspace to copy its post", context do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
    date = Date.add(eastern_today(), 10)

    huddl =
      generate(
        huddl(
          group_id: group.id,
          title: "Hack night",
          date: date,
          start_time: ~T[18:00:00],
          duration_minutes: 120,
          max_attendees: nil,
          actor: owner
        )
      )

    conn =
      context.conn
      |> sign_in(owner)
      |> visit("/organize/#{group.slug}/huddlz/#{huddl.id}")
      |> assert_has(".phx-connected")
      |> assert_has("#social-posts", text: "Copy post")

    assert {:ok, _} =
             PlaywrightEx.Frame.evaluate(conn.frame_id,
               expression: """
               window.readClipboard = navigator.clipboard.readText.bind(navigator.clipboard);
               navigator.clipboard.writeText('previous clipboard contents');
               """,
               timeout: 5_000
             )

    expected =
      "Hack night\n#{Calendar.strftime(date, "%a, %b %-d")} at 6:00 PM\n" <>
        "#{huddl.physical_location}\n#{HuddlzWeb.Endpoint.url()}/groups/#{group.slug}/huddlz/#{huddl.id}"

    Map.merge(context, %{conn: conn, expected_post: expected})
  end

  step "I copy the post from the Social posts panel", context do
    Map.put(context, :conn, click_button(context.conn, "#social-posts", "Copy post"))
  end

  step "my clipboard holds the huddl's title, time, place and link on separate lines", context do
    assert {:ok, copied} =
             PlaywrightEx.Frame.evaluate(context.conn.frame_id,
               expression: "window.readClipboard()",
               timeout: 5_000
             )

    assert copied == context.expected_post
    context
  end

  step "the Social posts panel confirms the post was copied", context do
    assert_has(context.conn, "#social-posts", text: "Copied!")
    context
  end

  step "the copy button returns to Copy post", context do
    assert_browser(
      context.conn,
      "document.querySelector('#social-posts-copy').textContent.trim() === 'Copy post'"
    )

    context
  end
end

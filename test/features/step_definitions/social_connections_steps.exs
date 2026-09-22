defmodule SocialConnectionsSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [dispatch: 4, redirected_to: 1]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Communities.Group

  # Connecting hands off to the platform's own consent screen and comes back
  # to huddlz with a code. The hand-off is followed by hand here: the redirect
  # to the platform is read for its state, the platform's answer is stubbed,
  # and the callback is requested the way the platform would.
  step "I connect the Slack channel {string} of {string} from the Social tab of {string}",
       %{args: [channel, workspace, group_name]} = context do
    group = lookup_group(group_name)
    session = visit(context.session, "/organize/#{group.slug}/social")

    session
    |> click_button("Connect a place")
    |> assert_has("a", text: "Slack")

    Req.Test.stub(Huddlz.Social, fn conn ->
      Req.Test.json(conn, %{
        "ok" => true,
        "team" => %{"name" => workspace},
        "incoming_webhook" => %{
          "channel" => channel,
          "url" => "https://hooks.slack.com/services/T000/B000/secret"
        }
      })
    end)

    session = follow_platform_handoff(session, group, :slack)

    session =
      session
      |> check("A week before")
      |> check("The morning of")
      |> click_button("Start posting")

    Map.merge(context, %{session: session, conn: session, group: group})
  end

  step "the Social tab lists a connection to {string} on {word}",
       %{args: [channel, platform]} = context do
    assert_has(context.session, "#social-connections .row", text: channel)
    assert_has(context.session, "#social-connections .row", text: platform)
    context
  end

  step "the connection shows as posting", context do
    assert_has(context.session, "#social-connections .row", text: "Posting")
    context
  end

  step "the activity of {string} says {string}", %{args: [group_name, line]} = context do
    group = lookup_group(group_name)

    context.session
    |> visit("/organize/#{group.slug}")
    |> assert_has("#recent-activity .line", text: line)

    context
  end

  defp follow_platform_handoff(session, group, kind) do
    conn =
      dispatch(
        session.conn,
        HuddlzWeb.Endpoint,
        :get,
        "/organize/#{group.slug}/social/connect/#{kind}"
      )

    handoff = URI.parse(redirected_to(conn))
    assert handoff.host =~ Atom.to_string(kind)
    %{"state" => state} = URI.decode_query(handoff.query)

    callback =
      dispatch(
        session.conn,
        HuddlzWeb.Endpoint,
        :get,
        "/social/#{kind}/callback?code=platform-code&state=#{state}"
      )

    visit(session, redirected_to(callback))
  end

  defp lookup_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end
end

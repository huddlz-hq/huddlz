defmodule UnavailableNotificationTargetSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator

  alias Huddlz.Communities
  alias Huddlz.Notifications

  step "I have a notification for a deleted huddl named {string}",
       %{args: [title], current_user: user} = context do
    group =
      generate(
        group(
          owner_id: user.id,
          actor: user,
          is_public: true
        )
      )

    huddl =
      generate(
        huddl(
          creator_id: user.id,
          actor: user,
          group_id: group.id,
          title: title
        )
      )

    {:ok, _job} =
      Notifications.deliver(user, :rsvp_confirmation, %{
        "huddl_id" => huddl.id,
        "huddl_title" => huddl.title,
        "group_slug" => group.slug,
        "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at)
      })

    :ok = Communities.destroy_huddl(huddl, actor: user)

    context
  end
end

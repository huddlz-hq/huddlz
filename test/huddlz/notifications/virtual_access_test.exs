defmodule Huddlz.Notifications.VirtualAccessTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities
  alias Huddlz.Notifications
  alias Huddlz.Notifications.Senders

  setup do
    owner = generate(user(role: :user))
    attendee = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, actor: owner, is_public: true))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: owner.id,
          actor: owner,
          event_type: :virtual,
          virtual_link: "https://example.com/private-access",
          max_attendees: 1
        )
      )

    %{owner: owner, attendee: attendee, group: group, huddl: huddl}
  end

  test "waitlisted and cancelled recipients never receive a link in email or calendar attachments",
       ctx do
    Communities.join_waitlist_huddl!(ctx.huddl, actor: ctx.attendee)

    payload = %{
      "huddl_id" => ctx.huddl.id,
      "huddl_title" => ctx.huddl.title,
      "starts_at_iso" => DateTime.to_iso8601(ctx.huddl.starts_at),
      "ends_at_iso" => DateTime.to_iso8601(ctx.huddl.ends_at),
      "group_slug" => ctx.group.slug,
      "group_name" => ctx.group.name,
      "virtual_link" => ctx.huddl.virtual_link,
      "changed_fields" => ["virtual_link"]
    }

    senders = [
      Senders.HuddlUpdated,
      Senders.HuddlReminder1h,
      Senders.HuddlReminder24h,
      Senders.RsvpConfirmation,
      Senders.WaitlistPromoted
    ]

    for sender <- senders do
      refute email_content(sender.build(ctx.attendee, payload)) =~ ctx.huddl.virtual_link
    end

    Communities.cancel_rsvp_huddl!(ctx.huddl, actor: ctx.owner)

    for sender <- senders do
      assert email_content(sender.build(ctx.attendee, payload)) =~ ctx.huddl.virtual_link
    end

    Communities.cancel_rsvp_huddl!(ctx.huddl, actor: ctx.attendee)

    for sender <- senders do
      refute email_content(sender.build(ctx.attendee, payload)) =~ ctx.huddl.virtual_link
    end
  end

  test "update notifications do not persist private links in the recipient feed or queued payload",
       ctx do
    Communities.join_waitlist_huddl!(ctx.huddl, actor: ctx.attendee)
    Communities.update_huddl!(ctx.huddl, %{title: "Updated private huddl"}, actor: ctx.owner)

    %{results: notifications} =
      Notifications.list_for_user!(actor: ctx.attendee, page: [limit: 100])

    update = Enum.find(notifications, &(&1.trigger == "huddl_updated"))
    assert update
    refute inspect(update.payload) =~ ctx.huddl.virtual_link

    {:ok, job} =
      Notifications.deliver(ctx.attendee, :huddl_updated, %{
        "huddl_id" => ctx.huddl.id,
        "virtual_link" => ctx.huddl.virtual_link
      })

    refute inspect(job.args) =~ ctx.huddl.virtual_link
  end

  defp email_content(email) do
    Enum.join([email.html_body, email.text_body | Enum.map(email.attachments, & &1.data)], "\n")
  end
end

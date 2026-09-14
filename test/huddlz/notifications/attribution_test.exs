defmodule Huddlz.Notifications.AttributionTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts
  alias Huddlz.Notifications

  test "inbox attribution distinguishes people with the same name and follows restoration" do
    admin = generate(user(role: :admin))
    recipient = generate(user(display_name: "Morgan"))
    reported = generate(user(display_name: "Jordan"))
    other = generate(user(display_name: "Jordan"))

    for {person, title} <- [{reported, "First huddl"}, {other, "Second huddl"}] do
      {:ok, _} =
        Notifications.deliver(recipient, :rsvp_received, %{
          "rsvper_id" => person.id,
          "rsvper_display_name" => "Jordan",
          "huddl_title" => title
        })
    end

    suspended = Accounts.suspend_user!(reported, "Mistaken identity", actor: admin)
    notifications = Notifications.list_for_user!(actor: recipient, page: false)
    titles = Enum.map(notifications, & &1.title)
    assert "Suspended account RSVPed to First huddl" in titles
    assert "Jordan RSVPed to Second huddl" in titles

    first = Enum.find(notifications, &(&1.payload["huddl_title"] == "First huddl"))

    assert Notifications.get_notification!(first.id, actor: recipient).title ==
             "Suspended account RSVPed to First huddl"

    Accounts.restore_user!(suspended, actor: admin)

    assert Notifications.get_notification!(first.id, actor: recipient).title ==
             "Jordan RSVPed to First huddl"
  end
end

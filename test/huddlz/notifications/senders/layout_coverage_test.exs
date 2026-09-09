defmodule Huddlz.Notifications.Senders.LayoutCoverageTest do
  @moduledoc """
  Every email the app sends renders through `Huddlz.Notifications.Layout`
  with a footer: the trigger registry's senders, the two authentication
  emails and the email-address invitation.

  Set `EMAIL_SAMPLES_DIR` to also write each rendered email to disk, for
  screenshots: `EMAIL_SAMPLES_DIR=/tmp/emails mix test <this file>`.
  """

  use Huddlz.DataCase, async: false

  alias Huddlz.Accounts.User.Senders.SendNewUserConfirmationEmail
  alias Huddlz.Accounts.User.Senders.SendPasswordResetEmail
  alias Huddlz.Communities
  alias Huddlz.Communities.GroupInvitation.EmailWorker
  alias Huddlz.Notifications.Triggers

  @chrome ~s(>huddlz</td>)
  @button "display:inline-block;padding:13px 22px"

  setup do
    owner = generate(user(role: :user, display_name: "Alex Rivera"))
    recipient = generate(user(role: :user, display_name: "Sam Okafor"))

    group =
      generate(
        group(
          name: "Pickup Sports",
          slug: "pickup-sports",
          is_public: true,
          owner_id: owner.id,
          actor: owner
        )
      )

    huddl =
      generate(
        huddl(
          title: "Saturday Soccer",
          group_id: group.id,
          creator_id: owner.id,
          actor: owner,
          date: Date.add(Huddlz.Generator.eastern_today(), 3),
          start_time: ~T[10:00:00],
          duration_minutes: 120
        )
      )

    huddl = Ash.load!(huddl, :group, authorize?: false)

    huddl_payload = %{
      "huddl_id" => huddl.id,
      "huddl_title" => to_string(huddl.title),
      "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at),
      "ends_at_iso" => DateTime.to_iso8601(huddl.ends_at),
      "time_zone" => huddl.time_zone,
      "event_type" => "in_person",
      "physical_location" => huddl.physical_location,
      "group_name" => to_string(group.name),
      "group_slug" => to_string(group.slug)
    }

    group_payload = %{
      "group_id" => group.id,
      "group_name" => to_string(group.name),
      "group_slug" => to_string(group.slug)
    }

    payloads = %{
      password_changed: %{},
      email_changed: %{"audience" => "old", "old_email" => "sam.old@example.com"},
      account_role_changed: %{"previous_role" => "user", "new_role" => "admin"},
      group_member_joined: Map.put(group_payload, "joiner_display_name", "Jordan Lee"),
      group_member_added: group_payload,
      group_invitation:
        Map.merge(group_payload, %{
          "invitation_id" => Ecto.UUID.generate(),
          "inviter_name" => owner.display_name,
          "role" => "member"
        }),
      group_member_removed: group_payload,
      group_role_changed:
        Map.merge(group_payload, %{"previous_role" => "member", "new_role" => "organizer"}),
      group_archived:
        Map.put(group_payload, "archived_at", DateTime.to_iso8601(DateTime.utc_now())),
      group_ownership_transferred:
        Map.merge(group_payload, %{"role" => "new_owner", "previous_owner_display_name" => "Alex"}),
      huddl_new: huddl_payload,
      huddl_updated: Map.put(huddl_payload, "changed_fields", ["starts_at", "physical_location"]),
      huddl_cancelled: Map.put(huddl_payload, "cancellation_reason", "Rain all weekend"),
      huddl_series_updated: Map.put(huddl_payload, "changed_fields", ["schedule"]),
      recurring_huddl_generation_failed: huddl_payload,
      huddl_reminder_24h: %{"huddl_id" => huddl.id},
      huddl_reminder_1h: %{"huddl_id" => huddl.id},
      rsvp_received: Map.put(huddl_payload, "rsvper_display_name", "Jordan Lee"),
      rsvp_cancelled: Map.put(huddl_payload, "rsvper_display_name", "Jordan Lee"),
      rsvp_confirmation: %{"huddl_id" => huddl.id},
      waitlist_promoted: %{"huddl_id" => huddl.id}
    }

    %{owner: owner, recipient: recipient, group: group, payloads: payloads}
  end

  test "every registered sender renders through the layout with a footer that fits its category",
       %{recipient: recipient, payloads: payloads} do
    # The digest senders are registered but deferred; they have no module yet.
    triggers =
      Triggers.all()
      |> Enum.filter(fn {_trigger, %{sender: sender}} -> Code.ensure_loaded?(sender) end)
      |> Map.new()

    missing = Map.keys(triggers) -- Map.keys(payloads)
    assert missing == [], "add a sample payload for: #{inspect(missing)}"

    for {trigger, %{sender: sender, category: category}} <- triggers do
      email = build(sender, recipient, payloads[trigger])
      save_sample(trigger, email)

      assert_layout(email, trigger)

      case category do
        :activity ->
          assert email.html_body =~ "/unsubscribe/", "#{trigger} lacks the unsubscribe link"
          assert email.text_body =~ "/unsubscribe/", "#{trigger} text lacks the unsubscribe link"
          assert email.html_body =~ "/profile/notifications"

        _transactional ->
          refute email.html_body =~ "unsubscribe", "#{trigger} is transactional"
          refute email.text_body =~ "unsubscribe", "#{trigger} is transactional"
          assert email.text_body =~ "You're receiving this email because"
      end
    end
  end

  test "huddl emails carry the huddl's facts: when, where and group", %{
    recipient: recipient,
    payloads: payloads
  } do
    for trigger <- [
          :huddl_new,
          :huddl_updated,
          :huddl_cancelled,
          :huddl_series_updated,
          :huddl_reminder_24h,
          :huddl_reminder_1h,
          :rsvp_confirmation,
          :waitlist_promoted
        ] do
      %{sender: sender} = Triggers.fetch!(trigger)
      email = build(sender, recipient, payloads[trigger])

      for label <- ["When", "Where", "Group"] do
        assert email.html_body =~ ">#{label}</td>", "#{trigger} lacks the #{label} fact"
        assert email.text_body =~ "#{label}:", "#{trigger} text lacks the #{label} fact"
      end

      assert email.html_body =~ "Pickup Sports"
      assert email.html_body =~ "Main St"
      assert email.html_body =~ "EDT" or email.html_body =~ "EST"
    end
  end

  test "the authentication emails render through the layout", %{recipient: recipient} do
    reset = SendPasswordResetEmail.build(recipient, "reset-token")
    save_sample(:password_reset, reset)
    assert_layout(reset, :password_reset)
    assert reset.html_body =~ @button
    assert reset.html_body =~ "/reset/reset-token"
    assert reset.text_body =~ "Reset password: "
    refute reset.html_body =~ "unsubscribe"

    confirm = SendNewUserConfirmationEmail.build(recipient, "confirm-token")
    save_sample(:new_user_confirmation, confirm)
    assert_layout(confirm, :new_user_confirmation)
    assert confirm.html_body =~ "/confirm_new_user/confirm-token"
    refute confirm.html_body =~ "unsubscribe"
  end

  test "the invitation to an address without an account renders through the layout", %{
    owner: owner
  } do
    private_group = generate(group(name: "Founder Coffee", is_public: false, actor: owner))

    invitation =
      Communities.invite_to_group_by_email!(private_group.id, "new.person@example.com", :member,
        actor: owner
      )

    invitation = Ash.load!(invitation, [:group, :inviter], authorize?: false)
    email = EmailWorker.build(invitation)
    save_sample(:email_invitation, email)

    assert_layout(email, :email_invitation)
    assert email.to == [{"", "new.person@example.com"}]
    assert email.html_body =~ "/invitations/email/"
    assert email.html_body =~ "Review invitation</a>"
    refute email.html_body =~ "unsubscribe"
  end

  # Keeps the compiler from tracing the registry's not-yet-written digest senders.
  defp build(sender, user, payload), do: sender.build(user, payload)

  defp assert_layout(email, name) do
    assert email.html_body =~ @chrome, "#{name} does not wear the layout"
    assert email.html_body =~ "<h1", "#{name} has no title"
    assert email.html_body =~ "huddlz · ", "#{name} has no footer"
    assert email.text_body =~ "\n--\n", "#{name} text has no footer"
    assert String.starts_with?(email.text_body, "huddlz\n"), "#{name} text has no header"
    refute email.text_body =~ "<", "#{name} leaks markup into plain text"
  end

  defp save_sample(name, email) do
    case System.get_env("EMAIL_SAMPLES_DIR") do
      nil ->
        :ok

      dir ->
        File.mkdir_p!(dir)
        File.write!(Path.join(dir, "#{name}.html"), email.html_body)

        File.write!(
          Path.join(dir, "#{name}.txt"),
          "Subject: #{email.subject}\n\n" <> email.text_body
        )
    end
  end
end

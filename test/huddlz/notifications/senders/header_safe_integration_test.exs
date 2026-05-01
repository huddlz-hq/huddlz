defmodule Huddlz.Notifications.Senders.HeaderSafeIntegrationTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Triggers

  @malicious "Eve\r\nBcc: x@evil.com"

  test "implemented registered senders strip CR/LF from built subjects" do
    user = generate(user(display_name: @malicious))
    huddl = setup_huddl(title: @malicious, group_name: @malicious)

    cases =
      Triggers.all()
      |> Enum.flat_map(fn {trigger, %{sender: sender}} ->
        if implemented_sender?(sender) do
          payload_variants(trigger, huddl)
          |> Enum.map(fn {variant, payload} -> {trigger, variant, sender, payload} end)
        else
          []
        end
      end)

    assert cases != []

    for {trigger, variant, sender, payload} <- cases do
      email = sender.build(user, payload)

      refute email.subject =~ "\r",
             "#{inspect(sender)} subject for #{trigger}/#{variant} contains CR: #{inspect(email.subject)}"

      refute email.subject =~ "\n",
             "#{inspect(sender)} subject for #{trigger}/#{variant} contains LF: #{inspect(email.subject)}"
    end
  end

  defp implemented_sender?(sender) do
    Code.ensure_loaded?(sender) and function_exported?(sender, :build, 2)
  end

  defp payload_variants(:email_changed, _huddl) do
    [
      {"new",
       Map.merge(malicious_payload(), %{"audience" => "new", "old_email" => "old@example.com"})}
    ]
  end

  defp payload_variants(:group_ownership_transferred, _huddl) do
    [
      {"previous_owner", Map.put(malicious_payload(), "role", "previous_owner")},
      {"new_owner", Map.put(malicious_payload(), "role", "new_owner")}
    ]
  end

  defp payload_variants(trigger, huddl)
       when trigger in [:huddl_reminder_24h, :huddl_reminder_1h, :rsvp_confirmation] do
    [{"default", %{"huddl_id" => huddl.id}}]
  end

  defp payload_variants(_trigger, _huddl), do: [{"default", malicious_payload()}]

  defp malicious_payload do
    %{
      "changed_fields" => ["title"],
      "group_id" => Ash.UUID.generate(),
      "group_name" => @malicious,
      "group_slug" => "evil-group",
      "huddl_id" => Ash.UUID.generate(),
      "huddl_title" => @malicious,
      "joiner_display_name" => @malicious,
      "new_owner_display_name" => @malicious,
      "new_role" => @malicious,
      "old_email" => "old@example.com",
      "previous_owner_display_name" => @malicious,
      "previous_role" => @malicious,
      "rsvper_display_name" => @malicious,
      "starts_at_iso" => "2030-05-04T17:00:00Z"
    }
  end

  defp setup_huddl(attrs) do
    owner = generate(user(role: :user))

    group =
      generate(
        group(
          name: Keyword.fetch!(attrs, :group_name),
          slug: "evil-group",
          is_public: true,
          owner_id: owner.id,
          actor: owner
        )
      )

    generate(
      huddl(
        title: Keyword.fetch!(attrs, :title),
        group_id: group.id,
        creator_id: owner.id,
        actor: owner
      )
    )
  end
end

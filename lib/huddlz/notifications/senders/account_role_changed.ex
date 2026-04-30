defmodule Huddlz.Notifications.Senders.AccountRoleChanged do
  @moduledoc """
  Sender for A5: an admin changed this user's account role.

  Activity-category email — respects the user's notification preferences and
  includes an unsubscribe link in the footer.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications

  @impl true
  def build(user, payload) do
    new_role = payload["new_role"] || to_string(user.role)
    previous_role = payload["previous_role"]

    ctx = %{
      name: user.display_name,
      new_role: new_role,
      previous_role: previous_role,
      settings_url: url(~p"/profile/notifications"),
      unsubscribe_url:
        url(~p"/unsubscribe/#{Notifications.unsubscribe_token(user, :account_role_changed)}")
    }

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject("Your huddlz account role was updated")
    |> html_body(html_body(ctx))
    |> text_body(text_body(ctx))
  end

  defp html_body(ctx) do
    """
    <p>Hi #{safe(ctx.name)},</p>

    <p>An administrator just updated your huddlz account role #{html_change_phrase(ctx)}.</p>

    <p>If this looks wrong, reply to this email and we'll sort it out.</p>

    <hr/>
    <p style="font-size: 0.85em; color: #666;">
      You're receiving this because role-change notifications are on.
      <a href="#{ctx.settings_url}">Manage notification settings</a> ·
      <a href="#{ctx.unsubscribe_url}">Unsubscribe from these</a>
    </p>
    """
  end

  defp text_body(ctx) do
    """
    Hi #{ctx.name},

    An administrator just updated your huddlz account role #{text_change_phrase(ctx)}.

    If this looks wrong, reply to this email and we'll sort it out.

    --
    You're receiving this because role-change notifications are on.
    Manage notification settings: #{ctx.settings_url}
    Unsubscribe from these: #{ctx.unsubscribe_url}
    """
  end

  defp html_change_phrase(%{previous_role: nil, new_role: new}),
    do: "to <strong>#{safe(new)}</strong>"

  defp html_change_phrase(%{previous_role: prev, new_role: new}),
    do: "from <strong>#{safe(prev)}</strong> to <strong>#{safe(new)}</strong>"

  defp text_change_phrase(%{previous_role: nil, new_role: new}), do: "to #{new}"
  defp text_change_phrase(%{previous_role: prev, new_role: new}), do: "from #{prev} to #{new}"

  defp safe(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end

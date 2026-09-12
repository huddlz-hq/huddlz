defmodule Huddlz.Accounts.EmailChangeTest do
  use Huddlz.DataCase, async: true
  alias Huddlz.Accounts
  alias Huddlz.Accounts.{EmailChange, User}

  test "an old signup confirmation cannot restore the original address after a completed change" do
    user = generate(user_with_password(password: "Password123!"))
    assert_receive {:email, %Swoosh.Email{subject: "Confirm your email address"} = email}
    original_token = email_token(email, "Confirm my email")

    {:ok, _pending} =
      Accounts.change_email(user, "replacement-#{user.id}@example.com", "Password123!",
        actor: user
      )

    {old_token, new_token} =
      approval_tokens(to_string(user.email), "replacement-#{user.id}@example.com")

    assert {:ok, _} = EmailChange.approve(old_token)
    assert {:ok, completed} = EmailChange.approve(new_token)

    {:ok, strategy} = AshAuthentication.Info.strategy(User, :confirm_new_user)

    assert {:error, _} =
             AshAuthentication.Strategy.action(strategy, :confirm, %{"confirm" => original_token})

    assert Accounts.get_user!(user.id).email == completed.email
  end

  test "replacement requests cannot combine approvals and queued mail keeps its original recipients" do
    user = generate(user_with_password(password: "Password123!"))
    first_email = "first-#{user.id}@example.com"
    second_email = "second-#{user.id}@example.com"
    {:ok, _} = Accounts.change_email(user, first_email, "Password123!", actor: user)
    {:ok, _} = Accounts.change_email(user, second_email, "Password123!", actor: user)
    {first_old, first_new} = approval_tokens(to_string(user.email), first_email)
    second_old = approval_token(to_string(user.email))
    second_new = approval_token(second_email)
    assert {:error, _} = EmailChange.approve(first_old)
    assert {:error, _} = EmailChange.approve(first_new)
    assert {:ok, pending} = EmailChange.approve(second_new)
    assert pending.email == user.email
    assert {:ok, completed} = EmailChange.approve(second_old)
    assert to_string(completed.email) == second_email
    assert {:error, _} = EmailChange.approve(second_new)
  end

  test "expired requests cannot complete or resend, even after one inbox approved" do
    user = generate(user_with_password(password: "Password123!"))
    new_email = "expired-#{user.id}@example.com"
    {:ok, _} = Accounts.change_email(user, new_email, "Password123!", actor: user)
    {old_token, new_token} = approval_tokens(to_string(user.email), new_email)
    {:ok, pending} = EmailChange.approve(old_token)

    expired =
      Ash.Seed.update!(pending, %{
        pending_email_change:
          Map.put(pending.pending_email_change, "expires_at", System.system_time(:second) - 1)
      })

    assert {:error, _} = EmailChange.approve(new_token)

    assert {:error, _} =
             expired
             |> Ash.Changeset.for_update(
               :resend_email_change,
               %{request_id: expired.pending_email_change["id"]},
               actor: expired
             )
             |> Ash.update()

    assert Accounts.get_user!(user.id).email == user.email
  end

  test "the fifth hourly resend is the last, even across replacement requests" do
    user = generate(user_with_password(password: "Password123!"))

    {:ok, pending} =
      Accounts.change_email(user, "limited-#{user.id}@example.com", "Password123!", actor: user)

    now = System.system_time(:second)

    pending =
      Ash.Seed.update!(pending, %{
        email_change_resends: [now - 61, now - 122, now - 183, now - 244]
      })

    assert {:ok, fifth} =
             pending
             |> Ash.Changeset.for_update(
               :resend_email_change,
               %{request_id: pending.pending_email_change["id"]},
               actor: pending
             )
             |> Ash.update()

    # Advance the fixture beyond the cooldown, keeping all five requests in the hour.
    fifth =
      Ash.Seed.update!(fifth, %{
        email_change_resends: Enum.map(fifth.email_change_resends, &(&1 - 61))
      })

    {:ok, replaced} =
      Accounts.change_email(fifth, "limited-again-#{user.id}@example.com", "Password123!",
        actor: fifth
      )

    assert {:error, _} =
             replaced
             |> Ash.Changeset.for_update(
               :resend_email_change,
               %{request_id: replaced.pending_email_change["id"]},
               actor: replaced
             )
             |> Ash.update()
  end

  test "sign-in, recovery and preferences stay with the original address until completion" do
    user = generate(user_with_password(password: "Password123!"))

    user =
      Ash.Seed.update!(user, %{
        confirmed_at: DateTime.utc_now(),
        notification_preferences: %{"huddl_reminder_24h" => false}
      })

    replacement = "identity-#{user.id}@example.com"
    {:ok, pending} = Accounts.change_email(user, replacement, "Password123!", actor: user)
    {old_token, new_token} = approval_tokens(to_string(user.email), replacement)
    assert pending.confirmed_at == user.confirmed_at
    assert {:ok, _} = sign_in(to_string(user.email))
    assert {:error, _} = sign_in(replacement)
    request_reset(replacement)
    refute_receive {:email, %Swoosh.Email{subject: "Reset your password"}}, 10
    request_reset(to_string(user.email))
    assert_receive {:email, %Swoosh.Email{subject: "Reset your password", to: [{"", original}]}}
    assert original == to_string(user.email)
    assert {:ok, partial} = EmailChange.approve(new_token)
    assert partial.confirmed_at == user.confirmed_at
    assert {:ok, completed} = EmailChange.approve(old_token)
    assert completed.confirmed_at
    assert completed.notification_preferences == %{"huddl_reminder_24h" => false}
    assert {:ok, _} = sign_in(replacement)
    assert {:error, _} = sign_in(to_string(user.email))
    request_reset(replacement)

    assert_receive {:email,
                    %Swoosh.Email{subject: "Reset your password", to: [{"", ^replacement}]}}
  end

  test "a stale signed-in record cannot request a change with a password that has been replaced" do
    user = generate(user_with_password(password: "Password123!"))

    user
    |> Ash.Changeset.for_update(
      :change_password,
      %{
        current_password: "Password123!",
        password: "Replacement123!",
        password_confirmation: "Replacement123!"
      },
      actor: user
    )
    |> Ash.update!()

    assert {:error, _} =
             Accounts.change_email(user, "stale-password-#{user.id}@example.com", "Password123!",
               actor: user
             )

    assert Accounts.get_user!(user.id).email == user.email
  end

  test "consumed approval links cannot approve again or report the still-pending request" do
    user = generate(user_with_password(password: "Password123!"))
    replacement = "single-use-#{user.id}@example.com"
    {:ok, _} = Accounts.change_email(user, replacement, "Password123!", actor: user)
    {old_token, new_token} = approval_tokens(to_string(user.email), replacement)
    assert {:ok, _} = EmailChange.approve(old_token)
    assert {:error, _} = EmailChange.approve(old_token)
    assert {:error, _} = EmailChange.report(old_token)
    assert {:ok, completed} = EmailChange.approve(new_token)
    assert to_string(completed.email) == replacement
  end

  defp sign_in(email) do
    User
    |> Ash.Query.for_read(:sign_in_with_password, %{email: email, password: "Password123!"})
    |> Ash.read_one()
  end

  defp request_reset(email) do
    User
    |> Ash.ActionInput.for_action(:request_password_reset_token, %{email: email})
    |> Ash.run_action!()
  end

  defp approval_tokens(old_email, new_email) do
    Oban.drain_queue(queue: :notifications)
    {approval_token(old_email), approval_token(new_email)}
  end

  defp approval_token(recipient) do
    assert_receive {:email,
                    %Swoosh.Email{
                      subject: "Approve your huddlz email change",
                      to: [{"", ^recipient}]
                    } = email}

    email_token(email, "Review email change")
  end

  defp email_token(email, label) do
    [url] =
      email.html_body
      |> Floki.parse_document!()
      |> Floki.find("a")
      |> Enum.filter(&(Floki.text(&1) == label))
      |> Floki.attribute("href")

    url |> URI.parse() |> Map.fetch!(:path) |> String.split("/") |> List.last()
  end
end

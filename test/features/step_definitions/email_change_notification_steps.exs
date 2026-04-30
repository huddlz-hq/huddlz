defmodule EmailChangeNotificationSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions

  alias Huddlz.Accounts.User

  step "the user {string} has password {string}",
       %{args: [email, password]} = context do
    user = find_user!(context.users, email)

    {:ok, user_with_password} =
      user
      |> Ash.Changeset.for_update(
        :set_password,
        %{password: password, password_confirmation: password},
        actor: user
      )
      |> Ash.update()

    users =
      Enum.map(context.users, fn u ->
        if u.id == user.id, do: user_with_password, else: u
      end)

    {:ok, %{context | users: users}}
  end

  step "{string} changes their email to {string} with password {string}",
       %{args: [old_email, new_email, password]} = context do
    user = find_user!(context.users, old_email)

    case Ash.Changeset.for_update(
           user,
           :change_email,
           %{email: new_email, current_password: password},
           actor: user
         )
         |> Ash.update() do
      {:ok, _} -> {:ok, context}
      # The same-email case is rejected by the unique-email identity, but
      # that doesn't matter for the "no email is sent" assertion below.
      {:error, _} -> {:ok, context}
    end
  end

  step "a security notice should be sent to {string} naming the new address {string}",
       %{args: [recipient, new_email]} = context do
    Oban.drain_queue(queue: :notifications)

    receive_email_matching(recipient, fn email ->
      email.html_body =~ "security notice" and email.html_body =~ new_email
    end)

    {:ok, context}
  end

  step "a confirmation should be sent to {string} naming the previous address {string}",
       %{args: [recipient, old_email]} = context do
    Oban.drain_queue(queue: :notifications)

    receive_email_matching(recipient, fn email ->
      email.html_body =~ "now associated" and email.html_body =~ old_email
    end)

    {:ok, context}
  end

  step "no email-change notification should be sent", context do
    Oban.drain_queue(queue: :notifications)

    refute_email_matching(fn email ->
      email.subject == "Your huddlz email address was changed"
    end)

    {:ok, context}
  end

  defp find_user!(users, email) do
    case Enum.find(users, fn u -> to_string(u.email) == email end) do
      nil -> flunk("No user with email #{email} in scenario context")
      %User{} = user -> user
    end
  end

  defp receive_email_matching(recipient, predicate) do
    receive do
      {:email,
       %Swoosh.Email{
         subject: "Your huddlz email address was changed",
         to: [{"", ^recipient}]
       } = email} ->
        if predicate.(email) do
          :ok
        else
          flunk(
            "Email-change message to #{recipient} did not match expected content. Body:\n#{email.html_body}"
          )
        end

      {:email, _other} ->
        receive_email_matching(recipient, predicate)
    after
      100 -> flunk("No email-change notification received for #{recipient}")
    end
  end

  defp refute_email_matching(predicate) do
    receive do
      {:email, %Swoosh.Email{} = email} ->
        if predicate.(email) do
          flunk("Unexpected email-change notification sent: #{inspect(email.to)}")
        else
          refute_email_matching(predicate)
        end
    after
      50 -> :ok
    end
  end
end

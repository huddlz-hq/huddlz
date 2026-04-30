defmodule AccountRoleChangedNotificationSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions
  import Huddlz.Test.Helpers.FeatureUsers, only: [find_user!: 2]

  alias Huddlz.Accounts

  step "the admin {string} updates {string} to role {string}",
       %{args: [admin_email, target_email, new_role]} = context do
    admin = find_user!(context.users, admin_email)
    target = find_user!(context.users, target_email)
    role_atom = String.to_existing_atom(new_role)

    {:ok, _updated} = Accounts.update_role(target, role_atom, actor: admin)

    {:ok, context}
  end

  step "a role-change notification should be sent to {string} naming role {string}",
       %{args: [email, role]} = context do
    Oban.drain_queue(queue: :notifications)
    assert_role_change_email_received(email, role)
    {:ok, context}
  end

  step "no role-change notification should be sent", context do
    Oban.drain_queue(queue: :notifications)
    refute_role_change_email_received()
    {:ok, context}
  end

  defp assert_role_change_email_received(email_addr, role) do
    receive do
      {:email,
       %Swoosh.Email{
         subject: "Your huddlz account role was updated",
         to: [{"", ^email_addr}],
         html_body: body
       }} ->
        assert body =~ role,
               "role-change email body missing role #{inspect(role)}"

        :ok

      {:email, _other} ->
        assert_role_change_email_received(email_addr, role)
    after
      100 ->
        flunk("No role-change email received for #{email_addr}")
    end
  end

  defp refute_role_change_email_received do
    receive do
      {:email, %Swoosh.Email{subject: "Your huddlz account role was updated"} = email} ->
        flunk("Unexpected role-change email sent to #{inspect(email.to)}")

      {:email, _other} ->
        refute_role_change_email_received()
    after
      50 -> :ok
    end
  end
end

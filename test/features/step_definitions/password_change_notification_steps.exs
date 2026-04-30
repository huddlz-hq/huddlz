defmodule PasswordChangeNotificationSteps do
  use Cucumber.StepDefinition
  import ExUnit.Assertions

  step "a password-changed notification should be sent to {string}",
       %{args: [email]} = context do
    # The test process accumulates other emails (e.g. registration
    # confirmation) during the scenario. Walk the mailbox and pick out the
    # password-changed one rather than asserting the first message matches.
    assert_password_changed_email_received(email)
    {:ok, context}
  end

  defp assert_password_changed_email_received(email_addr) do
    receive do
      {:email,
       %Swoosh.Email{
         subject: "Your huddlz password was changed",
         to: [{"", ^email_addr}],
         html_body: body
       }} ->
        assert body =~ "security notice",
               "password-changed email body missing 'security notice'"

        :ok

      {:email, _other} ->
        assert_password_changed_email_received(email_addr)
    after
      100 ->
        flunk("No password-changed email received for #{email_addr}")
    end
  end
end

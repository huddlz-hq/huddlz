defmodule Huddlz.Notifications.Senders.GroupInvitationTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.GroupInvitation

  defp payload(overrides \\ %{}) do
    Map.merge(
      %{
        "invitation_id" => "invitation-1",
        "group_name" => "Quiet Makers",
        "inviter_name" => "Group Owner",
        "role" => "member"
      },
      overrides
    )
  end

  describe "build/2" do
    test "builds the invitation email contract" do
      user = generate(user(email: "invitee@example.com", display_name: "Invited User"))
      email = GroupInvitation.build(user, payload())

      assert email.to == [{"", "invitee@example.com"}]
      assert email.from == Mailer.from()
      assert email.subject == "Invitation to Quiet Makers"
      assert email.html_body =~ "Hi Invited User"
      assert email.html_body =~ "Review invitation"
      assert email.html_body =~ "/invitations/invitation-1"
      assert email.text_body =~ "Hi Invited User"
      assert email.text_body =~ "Quiet Makers"
      refute email.text_body =~ "<"
    end

    test "includes the activity notification footer" do
      user = generate(user())
      email = GroupInvitation.build(user, payload())

      assert email.html_body =~ "/unsubscribe/"
      assert email.text_body =~ "/profile/notifications"
    end

    test "html-escapes user-controlled strings and the invitation URL" do
      user = generate(user(display_name: "<script>user</script>"))

      email =
        GroupInvitation.build(
          user,
          payload(%{
            "group_name" => "<img src=x>",
            "inviter_name" => "<b>Owner</b>",
            "invitation_id" => "\" onmouseover=\"alert(1)"
          })
        )

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x>"
      refute email.html_body =~ "<b>Owner</b>"
      refute email.html_body =~ ~s|onmouseover="alert(1)|
      assert email.html_body =~ "&lt;script&gt;"
      assert email.html_body =~ "&lt;img"
      assert email.html_body =~ "&lt;b&gt;"
      assert email.html_body =~ "&quot; onmouseover=&quot;alert(1)"
    end
  end
end

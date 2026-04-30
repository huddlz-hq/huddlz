defmodule Huddlz.Notifications.Senders.GroupOwnershipTransferredTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Notifications.Senders.GroupOwnershipTransferred

  defp base_payload(overrides) do
    Map.merge(
      %{
        "group_id" => "g-1",
        "group_name" => "The Council",
        "group_slug" => "the-council",
        "previous_owner_display_name" => "Old Owner",
        "new_owner_display_name" => "New Owner"
      },
      overrides
    )
  end

  describe "previous_owner variant" do
    test "subject and copy describe the transfer to the new owner" do
      user = generate(user(display_name: "Sam"))
      email = GroupOwnershipTransferred.build(user, base_payload(%{"role" => "previous_owner"}))

      assert email.subject == "You transferred The Council to a new owner"
      assert email.html_body =~ "Hi Sam"
      assert email.html_body =~ "transferred ownership"
      assert email.html_body =~ "New Owner"
      assert email.text_body =~ "New Owner"
    end

    test "links to the group page" do
      user = generate(user())
      email = GroupOwnershipTransferred.build(user, base_payload(%{"role" => "previous_owner"}))

      assert email.html_body =~ "/groups/the-council"
    end

    test "no unsubscribe footer (transactional)" do
      user = generate(user())
      email = GroupOwnershipTransferred.build(user, base_payload(%{"role" => "previous_owner"}))

      refute email.html_body =~ "unsubscribe"
      refute email.text_body =~ "unsubscribe"
    end
  end

  describe "new_owner variant" do
    test "subject and copy welcome the new owner and credit the previous owner" do
      user = generate(user(display_name: "Pat"))
      email = GroupOwnershipTransferred.build(user, base_payload(%{"role" => "new_owner"}))

      assert email.subject == "You're the new owner of The Council"
      assert email.html_body =~ "Hi Pat"
      assert email.html_body =~ "Old Owner"
      assert email.html_body =~ "transferred ownership"
    end

    test "no unsubscribe footer (transactional)" do
      user = generate(user())
      email = GroupOwnershipTransferred.build(user, base_payload(%{"role" => "new_owner"}))

      refute email.html_body =~ "unsubscribe"
    end
  end

  describe "html escape" do
    test "escapes user-controlled fields in both variants" do
      user = generate(user(display_name: "<script>alert(1)</script>"))

      payload =
        base_payload(%{
          "role" => "new_owner",
          "group_name" => "<img src=x>",
          "previous_owner_display_name" => "<b>x</b>"
        })

      email = GroupOwnershipTransferred.build(user, payload)

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x>"
      refute email.html_body =~ "<b>x</b>"
      assert email.html_body =~ "&lt;script&gt;"
    end
  end
end

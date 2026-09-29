defmodule Huddlz.Notifications.Senders.SocialConnectionStoppedTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.SocialConnectionStopped

  @payload %{
    "group_name" => "Nashville Makers",
    "group_slug" => "nashville-makers",
    "channel_name" => "#meetups",
    "platform" => "Discord",
    "huddl_title" => "Intro to Ash"
  }

  test "tells the owner which connection stopped, on which huddl, and how to reconnect" do
    user = generate(user(display_name: "Sam"))
    email = SocialConnectionStopped.build(user, @payload)

    assert email.to == [{"", to_string(user.email)}]
    assert email.from == Mailer.from()
    assert email.subject == "Posts to #meetups have stopped"
    assert email.html_body =~ "Hi Sam"
    assert email.text_body =~ "could not post Intro to Ash to #meetups on Discord"
    assert email.text_body =~ "Reconnect #meetups"
    assert email.text_body =~ "/organize/nashville-makers/social"
    assert email.text_body =~ "because you own this group"
    refute email.text_body =~ "nsubscribe"
    refute email.text_body =~ "<"
  end

  test "escapes names the owner and organizers control" do
    user = generate(user(display_name: "<script>x</script>"))

    email =
      SocialConnectionStopped.build(user, %{
        @payload
        | "huddl_title" => "<img src=x>",
          "channel_name" => "<b>#meetups</b>"
      })

    refute email.html_body =~ "<script>"
    refute email.html_body =~ "<img src=x"
    refute email.html_body =~ "<b>#meetups"
    assert email.html_body =~ "&lt;script&gt;"
    assert email.html_body =~ "&lt;img"
  end
end

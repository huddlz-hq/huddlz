defmodule Huddlz.Notifications.Senders.RsvpConfirmationTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.RsvpConfirmation

  defp setup_huddl(attrs \\ %{}) do
    owner = generate(user(role: :user))

    group =
      generate(
        group(
          name: attrs[:group_name] || "Pickup Sports",
          slug: attrs[:group_slug] || "pickup-sports",
          is_public: true,
          owner_id: owner.id,
          actor: owner
        )
      )

    huddl_attrs =
      [
        title: attrs[:title] || "Saturday Soccer",
        group_id: group.id,
        creator_id: owner.id,
        actor: owner
      ]
      |> put_datetime_attrs(attrs)

    generate(huddl(huddl_attrs))
  end

  defp put_datetime_attrs(huddl_attrs, %{starts_at: starts_at} = attrs) do
    ends_at = attrs[:ends_at] || DateTime.add(starts_at, 2, :hour)

    Keyword.merge(huddl_attrs,
      date: DateTime.to_date(starts_at),
      start_time: starts_at |> DateTime.to_time() |> Time.truncate(:second),
      duration_minutes: DateTime.diff(ends_at, starts_at, :minute)
    )
  end

  defp put_datetime_attrs(huddl_attrs, _attrs), do: huddl_attrs

  describe "build/2" do
    test "addresses the user with their display name" do
      user = generate(user(display_name: "Sam"))
      huddl = setup_huddl()

      email = RsvpConfirmation.build(user, %{"huddl_id" => huddl.id})

      assert email.html_body =~ "Hi Sam"
      assert email.text_body =~ "Hi Sam"
    end

    test "to and from are correct" do
      user = generate(user())
      huddl = setup_huddl()

      email = RsvpConfirmation.build(user, %{"huddl_id" => huddl.id})

      assert email.to == [{"", to_string(user.email)}]
      assert email.from == Mailer.from()
    end

    test "subject confirms the rsvp and names the huddl" do
      user = generate(user())
      huddl = setup_huddl(%{title: "Saturday Soccer"})

      email = RsvpConfirmation.build(user, %{"huddl_id" => huddl.id})

      assert email.subject == "You're going to Saturday Soccer"
    end

    test "body links to the huddl page using slug + id" do
      user = generate(user())

      huddl =
        setup_huddl(%{
          title: "Saturday Soccer",
          group_name: "Pickup Sports",
          group_slug: "pickup-sports"
        })

      email = RsvpConfirmation.build(user, %{"huddl_id" => huddl.id})

      assert email.html_body =~ "Saturday Soccer"
      assert email.html_body =~ "Pickup Sports"
      assert email.html_body =~ "/groups/pickup-sports/huddlz/#{huddl.id}"
      assert email.text_body =~ "/groups/pickup-sports/huddlz/#{huddl.id}"
    end

    test "attaches an .ics calendar event" do
      user = generate(user())
      huddl = setup_huddl()

      email = RsvpConfirmation.build(user, %{"huddl_id" => huddl.id})

      assert [attachment] = email.attachments
      assert attachment.filename == "huddl.ics"
      assert attachment.content_type == "text/calendar"
      assert attachment.data =~ "BEGIN:VCALENDAR"
    end

    test "formats the start time in the payload time zone" do
      user = generate(user())

      starts_at = ~U[2030-05-04 17:00:00Z]
      huddl = setup_huddl(%{starts_at: starts_at, ends_at: DateTime.add(starts_at, 2, :hour)})

      email =
        RsvpConfirmation.build(user, %{
          "huddl_id" => huddl.id,
          "time_zone" => "America/New_York"
        })

      assert email.html_body =~ "May 4, 2030 at 1:00 PM EDT"
      assert email.text_body =~ "May 4, 2030 at 1:00 PM EDT"
    end

    test "includes the unsubscribe footer (activity)" do
      user = generate(user())
      huddl = setup_huddl()

      email = RsvpConfirmation.build(user, %{"huddl_id" => huddl.id})

      assert email.html_body =~ "/unsubscribe/"
      assert email.html_body =~ "/profile/notifications"
      assert email.text_body =~ "Unsubscribe"
    end

    test "html-escapes user-controlled strings in html_body" do
      user = generate(user(display_name: "<script>x</script>"))
      huddl = setup_huddl(%{title: "<img src=x>", group_name: "<b>Boom</b>"})

      email = RsvpConfirmation.build(user, %{"huddl_id" => huddl.id})

      refute email.html_body =~ "<script>"
      refute email.html_body =~ "<img src=x"
      refute email.html_body =~ "<b>Boom"
      assert email.html_body =~ "&lt;script&gt;"
    end

    test "leaves user-controlled strings raw in text_body" do
      user = generate(user(display_name: "Sam"))
      huddl = setup_huddl(%{title: "Sat & Sun"})

      email = RsvpConfirmation.build(user, %{"huddl_id" => huddl.id})

      assert email.text_body =~ "Sat & Sun"
      refute email.text_body =~ "<"
    end

    test "raises a clear error when huddl_id is missing" do
      user = generate(user())

      assert_raise ArgumentError, ~r/requires payload key "huddl_id"/, fn ->
        RsvpConfirmation.build(user, %{})
      end
    end

    test "raises a clear error when huddl_id is not binary" do
      user = generate(user())

      assert_raise ArgumentError, ~r/requires payload key "huddl_id"/, fn ->
        RsvpConfirmation.build(user, %{"huddl_id" => 123})
      end
    end
  end
end

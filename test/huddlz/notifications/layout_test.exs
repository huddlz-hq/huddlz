defmodule Huddlz.Notifications.LayoutTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Mailer
  alias Huddlz.Notifications.DateTimeFormatter
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @spec_base %{
    to: "sam@example.com",
    subject: "Tomorrow: Saturday Soccer",
    kicker: "Reminder · tomorrow",
    title: "Saturday Soccer starts tomorrow",
    paragraphs: [
      ["Hi Sam, you're going to ", {:strong, "Saturday Soccer"}, " with Pickup Sports."],
      "Here is what you need."
    ],
    facts: [
      {"When", "Sat Sep 12, 2026 at 10:00 AM EDT", "2 hours"},
      {"Where", "Laurelhurst Park"},
      {"Group", "Pickup Sports"}
    ],
    action: {"Open the huddl", "https://huddlz.test/groups/pickup-sports/huddlz/1"},
    aside: ["The calendar event is attached. ", {:link, "Open it", "https://huddlz.test/ics"}],
    footer: %{
      reason: "You're receiving this email because of your huddlz notification settings.",
      links: [{"Unsubscribe from this kind of email", "https://huddlz.test/unsubscribe/t"}]
    }
  }

  describe "email/1" do
    test "builds a Swoosh email with both bodies, the sender and a header-safe subject" do
      email = Layout.email(%{@spec_base | subject: "Tomorrow:\r\nBcc: x"})

      assert email.to == [{"", "sam@example.com"}]
      assert email.from == Mailer.from()
      assert email.subject == "Tomorrow: Bcc: x"
      assert email.html_body =~ "<!doctype html>"
      assert email.text_body =~ "Saturday Soccer starts tomorrow"
    end
  end

  describe "render/1 HTML" do
    setup do
      {html, text} = Layout.render(@spec_base)
      %{html: html, text: text}
    end

    test "wears the chrome: mark, kicker, title, facts, one button and the footer", %{html: html} do
      assert html =~ ~s(>huddlz</td>)
      assert html =~ "REMINDER · TOMORROW" or html =~ "Reminder · tomorrow"
      assert html =~ "<h1"
      assert html =~ "Saturday Soccer starts tomorrow</h1>"
      assert html =~ ">When</td>"
      assert html =~ "2 hours"
      assert html =~ ~s(href="https://huddlz.test/groups/pickup-sports/huddlz/1")
      assert html =~ "Open the huddl</a>"
      assert html =~ "Unsubscribe from this kind of email</a>"
      assert html =~ "huddlz notification settings"
    end

    test "uses inline styles on a table layout with no dark scheme", %{html: html} do
      assert html =~ ~s(<table role="presentation")
      assert html =~ ~s(<meta name="color-scheme" content="light">)
      refute html =~ "<style"
      refute html =~ "prefers-color-scheme"
    end

    test "renders strong and link segments", %{html: html} do
      assert html =~ "<strong style=\"font-weight:600;color:#0f1a1b;\">Saturday Soccer</strong>"

      assert html =~
               ~s(<a href="https://huddlz.test/ics" style="color:#0a6c72;text-decoration:underline;">Open it</a>)
    end

    test "escapes every string it is given" do
      {html, _text} =
        Layout.render(%{
          title: "<script>alert(1)</script>",
          kicker: "<b>k</b>",
          paragraphs: [
            ["Hi ", {:strong, "<i>Sam</i>"}, " ", {:link, "<x>", "https://a.test/?a=1&b=2"}]
          ],
          facts: [{"<When>", "<v>", "<s>"}],
          action: {"<Go>", "https://a.test/?q=<1>"},
          aside: "<aside>",
          footer: %{reason: "<why>", links: [{"<l>", "https://a.test/<u>"}]}
        })

      refute html =~ "<script>"
      refute html =~ "<b>k</b>"
      refute html =~ "<i>Sam</i>"
      refute html =~ "<aside>"
      assert html =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
      assert html =~ "https://a.test/?a=1&amp;b=2"
      assert html =~ "https://a.test/?q=&lt;1&gt;"
      assert html =~ "&lt;When&gt;"
      assert html =~ "&lt;why&gt;"
    end

    test "leaves out the pieces that are not given" do
      {html, text} = Layout.render(%{title: "Just a title", footer: Footer.account()})

      refute html =~ "<h1" == false
      refute html =~ "text-transform:uppercase"
      refute html =~ "border-radius:10px"
      refute html =~ "display:inline-block"
      assert html =~ "concerns your huddlz account"
      refute text =~ "unsubscribe"
    end
  end

  describe "render/1 plain text" do
    test "is the twin of the HTML: same pieces, no markup" do
      {_html, text} = Layout.render(@spec_base)

      assert text ==
               """
               huddlz

               REMINDER · TOMORROW
               Saturday Soccer starts tomorrow

               Hi Sam, you're going to Saturday Soccer with Pickup Sports.

               Here is what you need.

               When:  Sat Sep 12, 2026 at 10:00 AM EDT (2 hours)
               Where: Laurelhurst Park
               Group: Pickup Sports

               Open the huddl: https://huddlz.test/groups/pickup-sports/huddlz/1

               The calendar event is attached. Open it (https://huddlz.test/ics)

               --
               You're receiving this email because of your huddlz notification settings.
               Unsubscribe from this kind of email: https://huddlz.test/unsubscribe/t
               huddlz · #{elem(Mailer.from(), 1)}
               """

      refute text =~ "<"
    end

    test "writes a bare URL once when a link's text is its URL" do
      {_html, text} =
        Layout.render(%{
          title: "T",
          paragraphs: [
            ["Reset at ", {:link, "https://h.test/reset", "https://h.test/reset"}, "."]
          ]
        })

      assert text =~ "Reset at https://h.test/reset."
      refute text =~ "(https://h.test/reset)"
    end
  end

  describe "huddl_facts/1" do
    test "from a huddl row: when in the huddl's zone with the duration, where, and the group" do
      owner = generate(user(role: :user))

      group =
        generate(group(name: "Pickup Sports", is_public: true, owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            title: "Saturday Soccer",
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            date: Date.add(Huddlz.Generator.eastern_today(), 1),
            start_time: ~T[10:00:00],
            duration_minutes: 120
          )
        )

      huddl = Ash.load!(huddl, :group, authorize?: false)

      assert Layout.huddl_facts(huddl) == [
               {"When", DateTimeFormatter.format_starts_at(huddl.starts_at, huddl.time_zone),
                "2 hours"},
               {"Where", huddl.physical_location},
               {"Group", "Pickup Sports"}
             ]

      assert huddl.physical_location =~ "Main St"
    end

    test "from a payload, marking virtual and hybrid huddlz" do
      base = %{
        "starts_at_iso" => "2026-09-12T14:00:00Z",
        "ends_at_iso" => "2026-09-12T15:30:00Z",
        "time_zone" => "America/New_York",
        "group_name" => "Pickup Sports"
      }

      assert Layout.huddl_facts(Map.put(base, "event_type", "virtual")) == [
               {"When", "Sat Sep 12, 2026 at 10:00 AM EDT", "1 hour 30 minutes"},
               {"Where", "Online"},
               {"Group", "Pickup Sports"}
             ]

      assert Layout.huddl_facts(
               Map.merge(base, %{"event_type" => "hybrid", "physical_location" => "The Loft"})
             ) == [
               {"When", "Sat Sep 12, 2026 at 10:00 AM EDT", "1 hour 30 minutes"},
               {"Where", "The Loft", "Also online"},
               {"Group", "Pickup Sports"}
             ]
    end

    test "skips what the payload does not have" do
      assert Layout.huddl_facts(%{"group_name" => "Pickup Sports"}) == [
               {"Group", "Pickup Sports"}
             ]

      assert Layout.huddl_facts(%{}) == []
    end
  end
end

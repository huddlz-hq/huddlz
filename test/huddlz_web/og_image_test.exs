defmodule HuddlzWeb.OgImageTest do
  use ExUnit.Case, async: true

  alias HuddlzWeb.OgImage

  @group %{
    name: Ash.CiString.new("Phoenix Elixir Meetup"),
    member_count: 12,
    location: "Saint Augustine, FL",
    description:
      Ash.CiString.new("Monthly hands-on sessions for Elixir folks in the Phoenix ecosystem.")
  }

  @huddl %{
    title: "Hands-on with Ash Framework",
    starts_at: ~U[2030-09-10 22:30:00Z],
    ends_at: ~U[2030-09-11 00:30:00Z],
    time_zone: "America/New_York",
    status: :upcoming,
    event_type: :in_person,
    physical_location: "Saint Augustine, FL",
    group: %{name: Ash.CiString.new("Phoenix Elixir Meetup")}
  }

  test "draws the group, title, schedule and place in the local time zone" do
    svg = OgImage.huddl_svg(@huddl)

    assert svg =~ "PHOENIX ELIXIR MEETUP · IN PERSON"
    assert svg =~ ">PE<"
    assert svg =~ "Hands-on with Ash Framework"
    assert svg =~ "Tue, Sep 10 · 6:30 PM – 8:30 PM EDT"
    assert svg =~ "Saint Augustine, FL"
  end

  test "escapes markup in huddl titles" do
    svg = OgImage.huddl_svg(%{@huddl | title: ~s|Tom & Jerry <script>alert("x")</script>|})

    refute svg =~ "<script>"
    assert svg =~ "Tom &amp; Jerry"
    assert svg =~ "&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;"
  end

  test "wraps long titles onto two lines and ends a cut-off title with an ellipsis" do
    assert OgImage.wrap_title("Short title") == ["Short title"]

    assert OgImage.wrap_title("Building resilient LiveView applications together") ==
             ["Building resilient LiveView", "applications together"]

    assert [_first, second] =
             OgImage.wrap_title(
               "A very long huddl title that keeps going well past what the card can show"
             )

    assert String.ends_with?(second, "…")
    assert String.length(second) <= 28
  end

  test "names cancelled and completed huddlz in the eyebrow" do
    assert OgImage.huddl_svg(%{@huddl | status: :cancelled}) =~
             "PHOENIX ELIXIR MEETUP · CANCELLED"

    assert OgImage.huddl_svg(%{@huddl | status: :completed}) =~
             "PHOENIX ELIXIR MEETUP · COMPLETED"

    assert OgImage.huddl_svg(%{@huddl | event_type: :virtual}) =~ "PHOENIX ELIXIR MEETUP · ONLINE"
  end

  test "every card draws the brand mark from the one outline, never as text" do
    [_, glyph] = Regex.run(~r/<path d="([^"]+)" fill="#05191b"/, OgImage.mark_svg(512))

    for svg <- [OgImage.huddl_svg(@huddl), OgImage.group_svg(@group), OgImage.site_svg()] do
      assert svg =~ glyph
      refute svg =~ ~r/>h<\/text>/
    end
  end

  test "the ETag changes with what is drawn" do
    assert OgImage.etag(@huddl) == OgImage.etag(@huddl)
    refute OgImage.etag(@huddl) == OgImage.etag(%{@huddl | title: "Renamed"})
  end

  test "renders to a PNG of the advertised size" do
    {:ok, png} = OgImage.huddl_card(@huddl)
    {:ok, image} = Image.from_binary(png)

    assert {Image.width(image), Image.height(image)} == {OgImage.width(), OgImage.height()}
  end

  describe "group cards" do
    test "draws the member count, name, place and description" do
      svg = OgImage.group_svg(@group)

      assert svg =~ "GROUP · 12 MEMBERS"
      assert svg =~ ">PE<"
      assert svg =~ "Phoenix Elixir Meetup"
      assert svg =~ "Saint Augustine, FL"
      assert svg =~ "Monthly hands-on sessions for Elixir folks in the Phoenix ecosystem."
    end

    test "reads naturally for one member and for groups that meet online" do
      svg = OgImage.group_svg(%{@group | member_count: 1, location: nil, description: nil})

      assert svg =~ "GROUP · 1 MEMBER<"
      assert svg =~ "Meets online"
    end

    test "keeps the description to one line with an ellipsis" do
      long = String.duplicate("A community for people who like long words. ", 4)
      svg = OgImage.group_svg(%{@group | description: long})

      assert [_, line] = Regex.run(~r/fill="#7f8c8f">([^<]+)<\/text>/, svg)
      assert String.ends_with?(line, "…")
      assert String.length(line) <= 72
    end

    test "escapes markup in group names and descriptions" do
      svg =
        OgImage.group_svg(%{
          @group
          | name: "Tom & Jerry <b>fans</b>",
            description: ~s|<script>alert("x")</script>|
        })

      refute svg =~ "<script>"
      refute svg =~ "<b>"
      assert svg =~ "Tom &amp; Jerry"
    end

    test "the ETag changes with what is drawn" do
      assert OgImage.group_etag(@group) == OgImage.group_etag(@group)
      refute OgImage.group_etag(@group) == OgImage.group_etag(%{@group | member_count: 13})
    end

    test "renders to a PNG of the advertised size" do
      {:ok, png} = OgImage.group_card(@group)
      {:ok, image} = Image.from_binary(png)

      assert {Image.width(image), Image.height(image)} == {OgImage.width(), OgImage.height()}
    end
  end
end

defmodule HuddlzWeb.OgImageTest do
  use ExUnit.Case, async: true

  alias HuddlzWeb.OgImage

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

  test "the ETag changes with what is drawn" do
    assert OgImage.etag(@huddl) == OgImage.etag(@huddl)
    refute OgImage.etag(@huddl) == OgImage.etag(%{@huddl | title: "Renamed"})
  end

  test "renders to a PNG of the advertised size" do
    {:ok, png} = OgImage.huddl_card(@huddl)
    {:ok, image} = Image.from_binary(png)

    assert {Image.width(image), Image.height(image)} == {OgImage.width(), OgImage.height()}
  end
end

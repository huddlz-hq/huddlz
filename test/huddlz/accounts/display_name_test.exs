defmodule Huddlz.Accounts.DisplayNameTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts

  test "name changes reject contact links across common spellings" do
    person = generate(user(display_name: "Alex"))

    for name <- [
          "🔥 Bonus https://bit.ly/example 🔥",
          "HTTPS://EXAMPLE.COM",
          "www.example.test",
          "example.com",
          "(example.com/path)",
          "visit example.co.uk:443",
          "shop.example.photography",
          "例子.com",
          "пример.рф",
          "пример.xn--p1ai",
          "https://127.0.0.1",
          "//example.com",
          "Alex\nexample.com",
          "alex@example.test",
          "alex+hello@example.com",
          "mailto:alex@example.test"
        ] do
      assert {:error, error} = Accounts.update_display_name(person, name, actor: person)

      assert Enum.any?(error.errors, fn error ->
               Map.get(error, :field) == :display_name and
                 Map.get(error, :message) ==
                   "Choose a display name without links or email addresses."
             end),
             name
    end

    assert Accounts.get_user!(person.id, actor: person).display_name == "Alex"
  end

  test "name changes preserve legitimate international names, punctuation and handles" do
    person = generate(user(display_name: "Alex"))

    for name <- [
          "Dr. Smith",
          "J.R. Smith",
          "J.R.Smith",
          "Zoë Müller",
          "李小龍",
          "山田太郎",
          "محمد علي",
          "Jean-Luc O’Neill",
          "Jane’s Running Club",
          "🔥 Alex",
          "@alex",
          "alex_streams",
          "Smith & Co.",
          "comet",
          "alex.comedian"
        ] do
      assert {:ok, updated} = Accounts.update_display_name(person, name, actor: person)
      assert updated.display_name == name
    end
  end

  test "an existing invalid name does not prevent unrelated account changes" do
    person = generate(user(display_name: "Alex"))
    person = Ash.Seed.update!(person, %{display_name: "example.com"})

    updated =
      person
      |> Ash.Changeset.for_update(:update_theme_preference, %{theme_preference: :dark},
        actor: person
      )
      |> Ash.update!()

    assert updated.display_name == "example.com"
    assert updated.theme_preference == :dark
  end
end

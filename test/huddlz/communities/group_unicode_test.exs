defmodule Huddlz.Communities.GroupUnicodeTest do
  use Huddlz.DataCase, async: true
  alias Huddlz.Communities.Group

  describe "unicode group names" do
    test "handles unicode characters in group names correctly" do
      user = generate(user(role: :user))

      test_cases = [
        {"Café München", "cafe-munchen"},
        {"北京用户组", "bei-jing-yong-hu-zu"},
        {"Москва Tech", "moskva-tech"},
        {"🚀 Rocket Club", "rocket-club"},
        {"日本語グループ", "ri-ben-yu-gurupu"},
        {"한국어 모임", "hangugeo-moim"},
        {"Ελληνικά Group", "ellinika-group"}
      ]

      for {name, expected_slug} <- test_cases do
        {:ok, group} =
          Group
          |> Ash.Changeset.for_create(
            :create_group,
            %{
              name: name,
              description: "Test group with unicode name",
              location: "Test Location",
              is_public: true
            },
            actor: user
          )
          |> Ash.create()

        assert group.slug == expected_slug,
               "Expected slug '#{expected_slug}' for name '#{name}', got '#{group.slug}'"
      end
    end

    test "slugs are always auto-generated from name" do
      user = generate(user(role: :user))

      # Even if user provides a custom slug, it will be overridden
      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(
          :create_group,
          %{
            name: "北京用户组",
            # Custom slug will be ignored due to force_change_attribute
            slug: "beijing-users",
            description: "Beijing user group",
            location: "Beijing",
            is_public: true
          },
          actor: user
        )
        |> Ash.create()

      # Slug should be auto-generated from name, not the custom value
      assert group.slug == "bei-jing-yong-hu-zu"
    end

    test "handles empty slugs from unicode edge cases gracefully" do
      user = generate(user(role: :user))

      # If somehow a name produces an empty slug, it should fail validation
      assert {:error, _} =
               Group
               |> Ash.Changeset.for_create(
                 :create_group,
                 %{
                   # Only emojis might produce empty slug
                   name: "🔥🔥🔥",
                   description: "Test group",
                   location: "Test",
                   is_public: true
                 },
                 actor: user
               )
               |> Ash.create()
    end
  end
end

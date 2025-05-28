defmodule Huddlz.Communities.GroupUnicodeTest do
  use Huddlz.DataCase
  alias Huddlz.Communities.Group

  describe "unicode group names" do
    test "handles unicode characters in group names correctly" do
      user = create_verified_user()
      
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
        {:ok, group} = Group
          |> Ash.Changeset.for_create(:create_group, %{
            name: name,
            description: "Test group with unicode name",
            location: "Test Location",
            is_public: true,
            owner_id: user.id
          }, actor: user)
          |> Ash.create()
          
        assert group.slug == expected_slug, 
          "Expected slug '#{expected_slug}' for name '#{name}', got '#{group.slug}'"
      end
    end
    
    test "allows custom unicode slugs" do
      user = create_verified_user()
      
      # User can provide a custom slug that will be used as-is
      {:ok, group} = Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "北京用户组",
          slug: "beijing-users",  # Custom slug instead of auto-generated
          description: "Beijing user group",
          location: "Beijing",
          is_public: true,
          owner_id: user.id
        }, actor: user)
        |> Ash.create()
        
      assert group.slug == "beijing-users"
    end
    
    test "handles empty slugs from unicode edge cases gracefully" do
      user = create_verified_user()
      
      # If somehow a name produces an empty slug, it should fail validation
      assert {:error, _} = Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "🔥🔥🔥",  # Only emojis might produce empty slug
          description: "Test group",
          location: "Test",
          is_public: true,
          owner_id: user.id
        }, actor: user)
        |> Ash.create()
    end
  end
  
  defp create_verified_user do
    {:ok, user} = Huddlz.Accounts.User
      |> Ash.Changeset.for_create(:create, %{
        email: "test#{System.unique_integer([:positive])}@example.com",
        role: :verified,
        display_name: "Test User"
      })
      |> Ash.create(authorize?: false)
      
    user
  end
end
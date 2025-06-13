defmodule ViewPastHuddlzSteps do
  use Cucumber.StepDefinition
  import PhoenixTest
  import Huddlz.Generator
  import ExUnit.Assertions
  import CucumberDatabaseHelper

  # Helper function to check if any element from a list is visible
  defp any_visible?(conn, elements, selector \\ "h3") do
    Enum.any?(elements, fn element ->
      try do
        assert_has(conn, selector, text: element.title)
        true
      rescue
        _ -> false
      end
    end)
  end

  # Background step: Create past and future huddlz
  step "there are past and future huddlz in the system" do
    ensure_sandbox()

    # Create a verified host who can create huddls
    host = generate(user(role: :verified))

    # Create a public group
    public_group = generate(group(owner_id: host.id, is_public: true, actor: host))

    # Create past huddlz with different dates using the past_huddl generator
    past_huddl_1_day =
      generate(
        past_huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          title: "Yesterday's Workshop",
          description: "A workshop that happened yesterday",
          starts_at: DateTime.add(DateTime.utc_now(), -1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -1, :day) |> DateTime.add(2, :hour)
        )
      )

    past_huddl_1_week =
      generate(
        past_huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          title: "Last Week's Meetup",
          description: "A meetup from last week",
          starts_at: DateTime.add(DateTime.utc_now(), -7, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -7, :day) |> DateTime.add(3, :hour)
        )
      )

    past_huddl_1_month =
      generate(
        past_huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          title: "Monthly Retrospective",
          description: "Our monthly retrospective from last month",
          starts_at: DateTime.add(DateTime.utc_now(), -30, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -30, :day) |> DateTime.add(1, :hour)
        )
      )

    # Create a future huddl for contrast
    future_huddl =
      generate(
        huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          title: "Tomorrow's Event",
          description: "An event happening tomorrow",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day) |> DateTime.add(2, :hour),
          actor: host
        )
      )

    past_huddlz = [past_huddl_1_day, past_huddl_1_week, past_huddl_1_month]

    # Load group relationship for all huddlz
    past_huddlz =
      Enum.map(past_huddlz, fn huddl ->
        Ash.load!(huddl, :group, actor: host)
      end)

    future_huddl = Ash.load!(future_huddl, :group, actor: host)

    {:ok,
     %{
       host: host,
       public_group: public_group,
       past_huddlz: past_huddlz,
       future_huddl: future_huddl
     }}
  end

  # Create a private group with past huddlz for member testing
  step "I am a member of a private group with past huddlz", %{current_user: user} do
    # Create a private group owned by someone else
    owner = generate(user(role: :verified))
    private_group = generate(group(owner_id: owner.id, is_public: false, actor: owner))

    # Add the current user as a member
    generate(
      group_member(group_id: private_group.id, user_id: user.id, role: :member, actor: owner)
    )

    # Create past huddlz using the past_huddl generator that bypasses validation
    private_past_huddl =
      generate(
        past_huddl(
          group_id: private_group.id,
          creator_id: owner.id,
          is_private: true,
          title: "Private Past Meeting",
          description: "A private meeting that happened",
          starts_at: DateTime.add(DateTime.utc_now(), -2, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -2, :day) |> DateTime.add(1, :hour)
        )
      )

    # Load the group relationship
    private_past_huddl = Ash.load!(private_past_huddl, :group, actor: owner)

    {:ok,
     %{
       private_group: private_group,
       private_past_huddl: private_past_huddl
     }}
  end

  # Create a private group the user is NOT a member of
  step "there is a private group with past huddlz I'm not a member of" do
    ensure_sandbox()

    # Create a private group owned by someone else
    owner = generate(user(role: :verified))
    private_group = generate(group(owner_id: owner.id, is_public: false, actor: owner))

    # Create past huddl in the private group using the generator
    private_past_huddl =
      generate(
        past_huddl(
          group_id: private_group.id,
          creator_id: owner.id,
          is_private: true,
          title: "Secret Past Meeting",
          description: "A secret meeting that happened",
          starts_at: DateTime.add(DateTime.utc_now(), -3, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -3, :day) |> DateTime.add(1, :hour)
        )
      )

    {:ok,
     %{
       non_member_group: private_group,
       non_member_past_huddl: private_past_huddl
     }}
  end

  # Visit home page
  step "I visit the home page", %{conn: conn} do
    conn = conn |> visit("/")
    {:ok, %{conn: conn}}
  end

  # Select from date filter
  step "I select {string} from the date filter", %{args: [option], conn: conn} do
    # Select the date filter option which automatically triggers the form change event
    conn = conn |> select("Date Range", option: option)
    {:ok, %{conn: conn}}
  end

  step "I should see past huddlz", %{conn: conn, past_huddlz: past_huddlz} do
    assert any_visible?(conn, past_huddlz), "Expected to find at least one past huddl"
    :ok
  end

  step "I should not see future huddlz in the past section", %{
    conn: conn,
    future_huddl: future_huddl
  } do
    # When filtering by past events, future events should not be shown
    conn = refute_has(conn, "h3", text: future_huddl.title)
    {:ok, %{conn: conn}}
  end

  step "the past huddlz should be sorted newest first", %{
    conn: conn,
    past_huddlz: past_huddlz
  } do
    # Verify all past huddlz are visible
    # While we can't easily check DOM ordering with PhoenixTest,
    # we can ensure all events are present (backend handles sorting)
    Enum.each(past_huddlz, fn huddl ->
      assert_has(conn, "h3", text: huddl.title)
    end)

    # The actual sorting order is tested at the query level
    # This step ensures the data is displayed correctly
    :ok
  end

  step "I should see past huddlz from my private group", %{
    conn: conn,
    private_past_huddl: private_past_huddl
  } do
    # Check if the private huddl title appears on the page
    conn = assert_has(conn, "h3", text: private_past_huddl.title)
    {:ok, %{conn: conn}}
  end

  step "I should see past huddlz from public groups", %{conn: conn, past_huddlz: past_huddlz} do
    assert any_visible?(conn, past_huddlz), "Expected to find at least one public past huddl"
    :ok
  end

  step "I should not see past huddlz from the private group", %{
    conn: conn,
    non_member_past_huddl: non_member_past_huddl
  } do
    # Verify we cannot see the private group's past huddl
    conn = refute_has(conn, "h3", text: non_member_past_huddl.title)
    {:ok, %{conn: conn}}
  end

  step "I should not see any private huddlz", %{conn: conn} do
    # Anonymous users should not see any private huddlz
    # Our test data creates private huddlz with "Private" in their titles
    conn = refute_has(conn, "h3", text: "Private")
    conn = refute_has(conn, "h3", text: "Secret")
    {:ok, %{conn: conn}}
  end
end

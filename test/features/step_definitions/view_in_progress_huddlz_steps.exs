defmodule ViewInProgressHuddlzSteps do
  use Cucumber.StepDefinition
  import PhoenixTest
  import Huddlz.Generator
  import CucumberDatabaseHelper

  step "I visit the home page", %{conn: conn} do
    conn = conn |> visit("/")
    {:ok, %{conn: conn}}
  end

  step "there are huddlz in different states:", %{datatable: datatable} do
    ensure_sandbox()

    # Create a verified host
    host = generate(user(role: :user))

    # Create a public group
    public_group = generate(group(owner_id: host.id, is_public: true, actor: host))

    huddlz =
      Enum.map(datatable.maps, fn row ->
        case row["state"] do
          "future" ->
            # Event starts in 2 hours
            generate(
              huddl(
                group_id: public_group.id,
                creator_id: host.id,
                title: row["title"],
                starts_at: DateTime.add(DateTime.utc_now(), 2, :hour),
                ends_at: DateTime.add(DateTime.utc_now(), 4, :hour),
                actor: host
              )
            )

          "in_progress" ->
            # Event started 1 hour ago, ends in 1 hour
            generate(
              past_huddl(
                group_id: public_group.id,
                creator_id: host.id,
                title: row["title"],
                starts_at: DateTime.add(DateTime.utc_now(), -1, :hour),
                ends_at: DateTime.add(DateTime.utc_now(), 1, :hour)
              )
            )

          "past" ->
            # Event ended 1 hour ago
            generate(
              past_huddl(
                group_id: public_group.id,
                creator_id: host.id,
                title: row["title"],
                starts_at: DateTime.add(DateTime.utc_now(), -3, :hour),
                ends_at: DateTime.add(DateTime.utc_now(), -1, :hour)
              )
            )
        end
      end)

    {:ok, %{huddlz: huddlz, host: host, public_group: public_group}}
  end

  step "I should see {string} in the upcoming section", %{args: [title], conn: conn} do
    # The upcoming section is the default view
    conn = assert_has(conn, "h3", text: title)
    {:ok, %{conn: conn}}
  end

  step "I should not see {string} in the upcoming section", %{args: [title], conn: conn} do
    # The upcoming section is the default view
    conn = refute_has(conn, "h3", text: title)
    {:ok, %{conn: conn}}
  end
end

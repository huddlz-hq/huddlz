defmodule EditHuddlSteps do
  use Cucumber.StepDefinition
  import CucumberDatabaseHelper
  import Huddlz.Generator
  alias Huddlz.Communities.Huddl
  import PhoenixTest
  require Ash.Query

  step "the following huddlz exist:", context do
    ensure_sandbox()

    huddlz =
      context.datatable.maps
      |> Enum.map(fn huddl_data ->
        host =
          Enum.find(context.users, fn u ->
            to_string(u.display_name) == huddl_data["creator_name"]
          end)

        group =
          generate(
            group(owner_id: host.id, name: huddl_data["group_name"], is_public: true, actor: host)
          )

        generate(
          huddl(
            group_id: group.id,
            creator_id: host.id,
            is_private: false,
            title: huddl_data["name"],
            actor: host
          )
        )
      end)

    Map.put(context, :huddlz, huddlz)
  end

  step "I should be on the edit huddl page for {string}", %{args: [huddl_title]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: "Editing #{huddl_title}")
    context
  end

  step "I should be redirected to the {string} huddl page", %{args: [huddl_name]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: huddl_name)
    context
  end

  step "I save the form", context do
    form_data = Map.get(context, :form_data, %{})
    session = context[:session] || context[:conn]

    # First, select the event type if provided to ensure proper field visibility
    session =
      if form_data["event_type"] do
        event_type_label =
          case form_data["event_type"] do
            "in_person" -> "In-Person"
            "virtual" -> "Virtual"
            "hybrid" -> "Hybrid (Both In-Person and Virtual)"
            _ -> "In-Person"
          end

        select(session, "Event Type", option: event_type_label, exact: false)
      else
        session
      end

    # Fill in the form data
    session =
      Enum.reduce(form_data, session, fn {field, value}, session ->
        case field do
          "title" -> fill_in(session, "Title", with: value, exact: false)
          "description" -> fill_in(session, "Description", with: value, exact: false)
          "physical_location" -> fill_in(session, "Physical Location", with: value, exact: false)
          "virtual_link" -> fill_in(session, "Virtual Meeting Link", with: value, exact: false)
          "starts_at" -> fill_in(session, "Start Date & Time", with: value, exact: false)
          "ends_at" -> fill_in(session, "End Date & Time", with: value, exact: false)
          # Already handled above
          "event_type" -> session
          _ -> session
        end
      end)

    # Submit the form
    session = click_button(session, "Save Huddl")

    Map.merge(context, %{session: session, conn: session})
  end

  step "I try to visit the {string} edit huddl page", %{args: [huddl_name]} = context do
    user = context.current_user

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_name)
      |> Ash.Query.load(:group)
      |> Ash.read_one!(actor: user)

    session = context[:session] || context[:conn]
    session = session |> visit("/groups/#{huddl.group.slug}/huddlz/#{huddl.id}/edit")
    Map.merge(context, %{session: session, conn: session})
  end
end

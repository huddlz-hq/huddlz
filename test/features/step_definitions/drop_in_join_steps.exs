defmodule DropInJoinSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, GroupMember}

  step "I can join {string} from the huddl page", %{args: [_group_name]} = context do
    assert_has(context.session, "#huddl-group button", text: "Join group")
    context
  end

  step "I join {string} from the huddl page", %{args: [_group_name]} = context do
    session = within(context.session, "#huddl-group", &click_button(&1, "Join group"))
    Map.put(context, :session, session)
  end

  step "I am shown as a member of {string} on the huddl page", %{args: [_group_name]} = context do
    assert_has(context.session, "#huddl-group", text: "Member")
    refute_has(context.session, "#huddl-group button", text: "Join group")
    context
  end

  step "{string} belongs to {string}", %{args: [email, group_name]} = context do
    assert membership(email, group_name)
    context
  end

  defp membership(email, group_name) do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
    group = Group |> Ash.Query.filter(name == ^group_name) |> Ash.read_one!(authorize?: false)

    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.read_one!(authorize?: false)
  end
end

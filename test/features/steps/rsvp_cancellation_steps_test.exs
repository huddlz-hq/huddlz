defmodule RsvpCancellationSteps do
  use Cucumber, feature: "rsvp_cancellation.feature"
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Huddlz.Generator
  alias Huddlz.Communities.Huddl
  alias Huddlz.Accounts.User

  require Ash.Query

  # Given steps
  defstep "I have RSVPed to {string}", context do
    huddl_title = List.first(context.args)
    user = context.current_user

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.read_one!(actor: user)

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{user_id: user.id}, actor: user)
    |> Ash.update!()

    {:ok, context}
  end

  defstep "{string} has RSVPed to {string}", context do
    [email, huddl_title] = context.args

    user =
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.read_one!(actor: user)

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{user_id: user.id}, actor: user)
    |> Ash.update!()

    {:ok, context}
  end

  # When steps
  defstep "I visit the {string} huddl page", context do
    huddl_title = List.first(context.args)
    user = context.current_user

    huddl =
      Huddl
      |> Ash.Query.filter(title == ^huddl_title)
      |> Ash.Query.load(:group)
      |> Ash.read_one!(actor: user)

    {:ok, live, _html} =
      context.conn
      |> live("/groups/#{huddl.group_id}/huddlz/#{huddl.id}")

    {:ok, Map.put(context, :live, live)}
  end

  defstep "I click {string}", context do
    button_text = List.first(context.args)

    if button_text == "Cancel RSVP" do
      result =
        context.live
        |> element("button", "Cancel RSVP")
        |> render_click()

      {:ok, Map.put(context, :last_result, result)}
    else
      # Pass through to other step definitions
      :no_match
    end
  end
end

defmodule ConfirmationParticipationSteps do
  use Cucumber.StepDefinition

  import PhoenixTest
  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import HuddlzWeb.ApiCase

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  require Ash.Query

  step "{string} is confirmed for this visit", %{args: [email]} = context do
    user = Enum.find(context.users, &(to_string(&1.email) == email))
    Ash.Seed.update!(user, %{confirmed_at: DateTime.utc_now()})
    context
  end

  step "{string} fills while I check my email", %{args: [title]} = context do
    owner = Enum.find(context.users, &(to_string(&1.email) == "owner575@example.com"))

    huddl =
      Huddl
      |> Ash.Query.for_read(:read, %{}, actor: owner)
      |> Ash.Query.filter(title == ^title)
      |> Ash.read_one!()

    # The owner already attends. Reducing capacity to that one spot uses
    # the same public organizer action as editing the huddl in the UI.
    Communities.update_huddl!(huddl, %{max_attendees: 1}, actor: owner)
    context
  end

  step "unsafe confirmation destinations are submitted:", context do
    results =
      Enum.map(context.datatable.maps, fn row ->
        context.current_user
        |> Ash.Changeset.for_update(
          :remember_confirmation_destination,
          %{destination: row["destination"]},
          actor: context.current_user
        )
        |> Ash.update()
      end)

    Map.put(context, :destination_results, results)
  end

  step "each unsafe confirmation destination is refused", context do
    for result <- context.destination_results, do: assert({:error, %Ash.Error.Invalid{}} = result)
    context
  end

  step "confirmation lands on my normal agenda", context do
    assert_path(context.session, "/agenda")
    context
  end

  step "I start in a signed-out browser", context do
    Map.merge(context, %{current_user: nil, conn: build_conn(), session: build_conn()})
  end

  step "I confirm the email for {string} in another browser", %{args: [email]} = context do
    token =
      receive do
        {:email,
         %Swoosh.Email{subject: "Confirm your email address", to: [{_, ^email}], text_body: body}} ->
          [_, token] = Regex.run(~r{/confirm_new_user/([A-Za-z0-9._~-]+)}, body)
          token
      after
        1000 -> flunk("No confirmation email for #{email}")
      end

    session =
      build_conn() |> visit("/confirm_new_user/#{token}") |> click_button("Confirm my email")

    Map.merge(context, %{session: session, conn: session})
  end

  step "the unconfirmed owner tries public participation actions", context do
    owner = Enum.find(context.users, &(to_string(&1.email) == "owner575@example.com"))
    member = Enum.find(context.users, &(to_string(&1.email) == "member575@example.com"))

    huddl =
      Huddl
      |> Ash.Query.for_read(:read, %{}, actor: owner)
      |> Ash.Query.filter(title == "Making Night")
      |> Ash.read_one!()

    group = context.group

    results = [
      Communities.create_group("Another group", "Making", "Austin", "America/Chicago", true,
        actor: owner
      ),
      group
      |> Ash.Changeset.for_update(:update_details, %{name: "Changed name"}, actor: owner)
      |> Ash.update(),
      huddl
      |> Ash.Changeset.for_update(:update, %{title: "Changed title"}, actor: owner)
      |> Ash.update(),
      Communities.add_member(group.id, member.id, "member", actor: owner),
      Communities.join_group(group.id, actor: member),
      Huddlz.Communities.HuddlAttendee
      |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: member.id}, actor: member)
      |> Ash.create(),
      Communities.join_waitlist_huddl(huddl, %{}, actor: member),
      Huddlz.Accounts.ApiKey
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Test key", expires_at: DateTime.add(DateTime.utc_now(), 86_400)},
        actor: owner
      )
      |> Ash.create()
    ]

    api_response =
      build_conn()
      |> authenticated_conn(owner)
      |> Phoenix.ConnTest.dispatch(HuddlzWeb.Endpoint, :post, "/api/auth/api_keys", %{})

    Map.merge(context, %{role_results: results, key_response: api_response})
  end

  step "those participation actions are forbidden", context do
    for result <- context.role_results, do: assert({:error, %Ash.Error.Forbidden{}} = result)
    assert %{"errors" => [_ | _]} = json_response(context.key_response, 422)
    assert %{name: name} = Communities.get_by_slug!("makers-575", actor: context.current_user)
    assert to_string(name) == "Makers 575"
    context
  end

  step "the unconfirmed member tries to RSVP using earlier credentials", context do
    # The fixture still holds the original confirmed actor. Both credentials
    # predate the account's current unconfirmed state.
    stale_user = Enum.find(context.users, &(to_string(&1.email) == "member575@example.com"))

    huddl =
      Huddl
      |> Ash.Query.for_read(:read, %{}, actor: stale_user)
      |> Ash.Query.filter(title == "Making Night")
      |> Ash.read_one!()

    Ash.Seed.update!(stale_user, %{confirmed_at: DateTime.utc_now()})
    bearer_conn = authenticated_conn(build_conn(), stale_user)

    key =
      Huddlz.Accounts.ApiKey
      |> Ash.Changeset.for_create(
        :create,
        %{name: "Test key", expires_at: DateTime.add(DateTime.utc_now(), 86_400)},
        actor: stale_user
      )
      |> Ash.create!()

    Ash.Seed.update!(stale_user, %{confirmed_at: nil})

    query = ~s|mutation { rsvpToHuddl(id: "#{huddl.id}") { result { id } errors { message } } }|

    bearer = bearer_conn |> gql_post(query) |> json_response(200)

    api_key =
      build_conn()
      |> Plug.Conn.put_req_header(
        "authorization",
        "Bearer " <> key.__metadata__.plaintext_api_key
      )
      |> gql_post(query)
      |> json_response(200)

    action = Communities.rsvp_huddl(huddl, %{}, actor: stale_user)

    Map.merge(context, %{
      participation_responses: [bearer, api_key],
      participation_action: action,
      participation_huddl: huddl,
      participation_actor: stale_user
    })
  end

  step "every RSVP request is refused and no spot is reserved", context do
    for response <- context.participation_responses do
      assert response["data"]["rsvpToHuddl"]["result"] == nil
      assert [_ | _] = response["data"]["rsvpToHuddl"]["errors"]
    end

    assert {:error, _} = context.participation_action

    assert [] =
             Communities.check_user_rsvp!(context.participation_huddl.id,
               actor: context.participation_actor
             )

    context
  end
end

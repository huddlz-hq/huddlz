defmodule ApiKeysSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [build_conn: 0, get: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.{ApiKey, User}

  @endpoint HuddlzWeb.Endpoint

  step "I see my new key once", context do
    session = context.session
    [key] = session |> page_doc() |> Floki.attribute("#new-api-key", "value")
    assert String.starts_with?(key, "huddlz_")
    assert_has(session, "*", text: "This is the only time huddlz shows this key")
    Map.put(context, :new_key, key)
  end

  step "my new key works with the API", context do
    assert api_status(context.new_key) == 200
    context
  end

  step "the page no longer shows my new key", context do
    doc = page_doc(context.session)
    assert Floki.find(doc, "#new-api-key") == []
    refute Floki.raw_html(doc) =~ context.new_key
    context
  end

  step "{string} is listed as expiring in {int} days", %{args: [name, days]} = context do
    expires = Date.utc_today() |> Date.add(days) |> Calendar.strftime("%-d %b %Y")
    assert row_text(context.session, name) =~ "Expires #{expires}"
    context
  end

  step "I have no API keys", context do
    assert keys_of(context.current_user) == []
    context
  end

  step "I have an API key named {string}", %{args: [name]} = context do
    add_key(context, context.current_user, name, days_from_now(30))
  end

  step "I have an API key named {string} that expired yesterday", %{args: [name]} = context do
    add_key(context, context.current_user, name, days_from_now(-1))
  end

  step "{string} has an API key named {string}", %{args: [email, name]} = context do
    owner = Enum.find(context.users, &(to_string(&1.email) == email))
    add_key(context, owner, name, days_from_now(30))
  end

  step "{string} shows {string}", %{args: [name, text]} = context do
    assert row_text(context.session, name) =~ text
    context
  end

  step "{string} is marked expired", %{args: [name]} = context do
    assert row_text(context.session, name) =~ "Expired"
    context
  end

  step "my key {string} is used with the API", %{args: [name]} = context do
    assert api_status(context.keys[name]) == 200
    context
  end

  step "my key {string} is refused by the API", %{args: [name]} = context do
    assert api_status(context.keys[name]) == 401
    context
  end

  step "I click {string} for {string}", %{args: [action, name]} = context do
    session =
      within(context.session, "##{row_id(context.session, name)}", &click_button(&1, action))

    Map.merge(context, %{session: session, conn: session})
  end

  step "{string} is not listed", %{args: [name]} = context do
    assert find_row(context.session, name) == nil
    context
  end

  step "the sidebar has no {string} entry", %{args: [text]} = context do
    refute_has(context.session, "aside.sidebar a", text: text, exact: true)
    context
  end

  defp add_key(context, owner, name, expires_at) do
    record =
      ApiKey
      |> Ash.Changeset.for_create(:create, %{name: name, expires_at: expires_at}, actor: owner)
      |> Ash.create!()

    keys = Map.put(context[:keys] || %{}, name, record.__metadata__.plaintext_api_key)
    Map.put(context, :keys, keys)
  end

  defp keys_of(%User{} = user) do
    ApiKey |> Ash.Query.filter(user_id == ^user.id) |> Ash.read!(authorize?: false)
  end

  defp days_from_now(days), do: DateTime.add(DateTime.utc_now(), days * 86_400, :second)

  defp api_status(key) do
    build_conn()
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> key)
    |> get("/api/auth/me")
    |> Map.fetch!(:status)
  end

  # Each key is one item in the "Your keys" list; find it by its name.
  defp find_row(session, name) do
    session
    |> page_doc()
    |> Floki.find("ul[aria-label='Your keys'] > li")
    |> Enum.find(&(&1 |> Floki.find("h3") |> Floki.text() |> String.trim() == name))
  end

  defp row_text(session, name) do
    row = find_row(session, name) || flunk("#{name} is not listed")
    row |> Floki.text(sep: " ") |> String.replace(~r/\s+/, " ")
  end

  defp row_id(session, name) do
    row = find_row(session, name) || flunk("#{name} is not listed")
    [id] = Floki.attribute(row, "id")
    id
  end

  defp page_doc(session), do: session |> page_html() |> Floki.parse_document!()

  defp page_html(%PhoenixTest.Live{view: view}), do: Phoenix.LiveViewTest.render(view)
  defp page_html(%PhoenixTest.Static{conn: conn}), do: conn.resp_body
end

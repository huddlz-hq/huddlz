defmodule OrganizeWorkspaceSteps do
  use Cucumber.StepDefinition
  import PhoenixTest
  import Huddlz.Generator

  require Ash.Query

  step "the page should link {string} to its edit screen",
       %{args: [name]} = context do
    session = context[:session] || context[:conn]
    group = lookup_group(name)

    assert_has(session, "a[href='/groups/#{group.slug}/edit']", text: name)

    context
  end

  step "the past huddl {string} exists in group {string} hosted by {string}",
       %{args: [title, group_name, host_email]} = context do
    host = lookup_user(host_email)
    group = lookup_group(group_name)

    huddl =
      generate(
        past_huddl(
          title: title,
          group_id: group.id,
          creator_id: host.id,
          is_private: false
        )
      )

    huddls = Map.get(context, :huddls, [])
    Map.put(context, :huddls, [huddl | huddls])
  end

  step "the page should link {string} to its huddl edit screen",
       %{args: [title]} = context do
    session = context[:session] || context[:conn]
    huddl = lookup_huddl(title)

    assert_has(
      session,
      "a[href='/groups/#{huddl.group.slug}/huddlz/#{huddl.id}/edit']",
      text: title
    )

    context
  end

  step "the page should not link to {string}",
       %{args: [path]} = context do
    session = context[:session] || context[:conn]
    refute_has(session, "a[href='#{path}']")

    context
  end

  step "the picker should list {string} before {string}",
       %{args: [first, second]} = context do
    session = context[:session] || context[:conn]

    session
    |> assert_has("a.row .row-title", text: first, at: 1)
    |> assert_has("a.row .row-title", text: second, at: 2)

    context
  end

  defp lookup_group(name) do
    Huddlz.Communities.Group
    |> Ash.Query.filter(name: name)
    |> Ash.read_one!(authorize?: false)
  end

  defp lookup_user(email) do
    Huddlz.Accounts.User
    |> Ash.Query.filter(email: email)
    |> Ash.read_one!(authorize?: false)
  end

  defp lookup_huddl(title) do
    Huddlz.Communities.Huddl
    |> Ash.Query.filter(title: title)
    |> Ash.Query.load(:group)
    |> Ash.read_one!(authorize?: false)
  end
end

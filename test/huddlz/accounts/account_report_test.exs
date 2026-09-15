defmodule Huddlz.Accounts.AccountReportTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator

  alias Huddlz.Accounts
  alias Huddlz.Accounts.AccountReport
  alias Huddlz.Communities.{GroupMember, HuddlAttendee}

  require Ash.Query

  setup do
    admin = generate(user(role: :admin))
    owner = generate(user())
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    reporter = generate(user())
    reported = generate(user())
    join!(group, reporter)
    join!(group, reported)
    %{admin: admin, owner: owner, group: group, reporter: reporter, reported: reported}
  end

  describe "report" do
    test "records reason, details and a two-year expiry", ctx do
      {:ok, report} = report(ctx.reporter, ctx.reported, reason: :spam, details: "Coin listings")

      assert report.reason == :spam
      assert report.details == "Coin listings"
      assert report.reporter_id == ctx.reporter.id
      assert report.handled_at == nil
      assert_in_delta DateTime.diff(report.expires_at, DateTime.utc_now(), :day), 730, 2
    end

    test "needs a reason", ctx do
      assert {:error, %Ash.Error.Invalid{errors: errors}} = report(ctx.reporter, ctx.reported)
      assert Enum.any?(errors, &(&1.field == :reason))
    end

    test "sending again while a report is open changes nothing", ctx do
      {:ok, first} = report(ctx.reporter, ctx.reported, reason: :spam, details: "first")
      {:ok, again} = report(ctx.reporter, ctx.reported, reason: :other, details: "second")

      assert again.id == first.id
      assert again.reason == :spam
      assert again.details == "first"
      assert [_one] = reports_about(ctx.reported)
    end

    test "a handled report leaves room for a new one", ctx do
      {:ok, first} = report(ctx.reporter, ctx.reported, reason: :spam)
      {:ok, _handled} = Accounts.mark_report_handled(first, actor: ctx.admin)
      {:ok, second} = report(ctx.reporter, ctx.reported, reason: :other)

      refute second.id == first.id
      assert [_, _] = reports_about(ctx.reported)
    end

    test "an expired open report is replaced rather than duplicated", ctx do
      {:ok, old} = report(ctx.reporter, ctx.reported, reason: :spam, details: "old")
      long_ago = DateTime.shift(DateTime.utc_now(), year: -3)

      Ash.Seed.update!(old, %{
        inserted_at: long_ago,
        expires_at: DateTime.shift(long_ago, year: 2)
      })

      {:ok, fresh} = report(ctx.reporter, ctx.reported, reason: :other, details: "new")

      assert fresh.id == old.id
      assert fresh.reason == :other
      assert fresh.details == "new"
      assert DateTime.after?(fresh.expires_at, DateTime.utc_now())
      assert [%{id: id}] = Accounts.list_account_reports!(false, actor: ctx.admin)
      assert id == old.id
    end

    test "is for confirmed members only", ctx do
      unconfirmed = Ash.Seed.update!(ctx.reporter, %{confirmed_at: nil})

      assert {:error, %Ash.Error.Forbidden{}} =
               report(unconfirmed, ctx.reported, reason: :spam)
    end

    test "is refused for accounts the reporter cannot already see", ctx do
      stranger = generate(user())
      assert {:error, %Ash.Error.Forbidden{}} = report(stranger, ctx.reported, reason: :spam)
      assert {:error, %Ash.Error.Forbidden{}} = report(ctx.reporter, stranger, reason: :spam)
    end

    test "is refused for oneself", ctx do
      assert {:error, %Ash.Error.Forbidden{}} =
               report(ctx.reporter, ctx.reporter, reason: :spam)
    end

    test "reaches someone met on a who's going list", ctx do
      going = generate(user())
      host = generate(user())
      huddl = generate(huddl(group_id: ctx.group.id, creator_id: ctx.owner.id, actor: ctx.owner))
      rsvp!(huddl, going)
      rsvp!(huddl, host)

      assert {:ok, _report} = report(going, host, reason: :other)
      assert {:ok, _report} = report(going, ctx.owner, reason: :other)
    end
  end

  describe "queue" do
    test "administrators read open and handled reports, newest first", ctx do
      other = generate(user())
      join!(ctx.group, other)
      {:ok, first} = report(ctx.reporter, ctx.reported, reason: :spam)
      {:ok, second} = report(other, ctx.reported, reason: :other)

      assert [%{id: second_id}, %{id: first_id}] =
               Accounts.list_account_reports!(false, actor: ctx.admin)

      assert {second_id, first_id} == {second.id, first.id}
      assert [] = Accounts.list_account_reports!(true, actor: ctx.admin)

      {:ok, handled} = Accounts.mark_report_handled(first, actor: ctx.admin)
      assert handled.handled_by_id == ctx.admin.id
      assert [%{id: ^second_id}] = Accounts.list_account_reports!(false, actor: ctx.admin)
      assert [%{id: ^first_id}] = Accounts.list_account_reports!(true, actor: ctx.admin)
    end

    test "is closed to everyone else, reporter and reported included", ctx do
      {:ok, report} = report(ctx.reporter, ctx.reported, reason: :spam)

      for actor <- [ctx.reporter, ctx.reported, ctx.owner] do
        assert {:ok, []} = Accounts.list_account_reports(false, actor: actor)
        assert {:error, _not_found} = Ash.get(AccountReport, report.id, actor: actor)

        assert {:error, %Ash.Error.Forbidden{}} =
                 Accounts.mark_report_handled(report, actor: actor)
      end
    end

    test "marks a report handled once", ctx do
      {:ok, report} = report(ctx.reporter, ctx.reported, reason: :spam)
      {:ok, handled} = Accounts.mark_report_handled(report, actor: ctx.admin)

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.mark_report_handled(handled, actor: ctx.admin)
    end

    test "suspending the account leaves its reports open", ctx do
      {:ok, report} = report(ctx.reporter, ctx.reported, reason: :spam)
      {:ok, _suspended} = Accounts.suspend_user(ctx.reported, "Spam", actor: ctx.admin)

      assert [%{id: id, reported_user: %{open_report_count: 1}}] =
               Accounts.list_account_reports!(false,
                 actor: ctx.admin,
                 load: [reported_user: [:open_report_count]]
               )

      assert id == report.id
    end
  end

  defp report(reporter, reported, attrs \\ []) do
    Accounts.report_account(
      Map.merge(%{reported_user_id: reported.id}, Map.new(attrs)),
      actor: reporter
    )
  end

  defp reports_about(user) do
    AccountReport
    |> Ash.Query.filter(reported_user_id == ^user.id)
    |> Ash.read!(authorize?: false)
  end

  defp join!(group, user) do
    Ash.Seed.seed!(GroupMember, %{group_id: group.id, user_id: user.id, role: :member})
  end

  defp rsvp!(huddl, user) do
    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: user.id})
    |> Ash.create!(authorize?: false)
  end
end

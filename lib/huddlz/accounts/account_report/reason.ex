defmodule Huddlz.Accounts.AccountReport.Reason do
  @moduledoc "What a reporter says is wrong: spam or advertising, or something else."
  use Ash.Type.Enum, values: [spam: "Spam or advertising", other: "Other"]

  def graphql_type(_), do: :account_report_reason
end

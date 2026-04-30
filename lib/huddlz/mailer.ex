defmodule Huddlz.Mailer do
  use Swoosh.Mailer, otp_app: :huddlz

  @doc """
  Default `{name, address}` tuple for outbound email senders.

  Reads `:huddlz, :email` config and falls back to safe defaults so dev/test
  environments work without configuration.
  """
  @spec from() :: {String.t(), String.t()}
  def from do
    config = Application.get_env(:huddlz, :email, [])
    name = config[:from_name] || "huddlz support"
    address = config[:from_address] || "support@huddlz.com"
    {name, address}
  end
end

defmodule HuddlzWeb.TestErrorController do
  @moduledoc false

  use HuddlzWeb, :controller

  def show(_conn, _params), do: raise("private runtime failure")
end

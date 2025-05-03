defmodule HuddlzWeb.PageController do
  use HuddlzWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

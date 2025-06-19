defmodule HuddlzWeb.NotFoundError do
  @moduledoc """
  Exception raised when a resource is not found or user is not authorized to access it.
  This triggers Phoenix's 404 error page.
  """
  defexception plug_status: 404, message: "Not Found"
end

defmodule Huddlz.MailerTest do
  use ExUnit.Case, async: true

  test "Mailgun adapter runtime dependencies are available" do
    assert Code.ensure_loaded?(Plug.Conn.Query)
    assert Code.ensure_loaded?(Multipart.Part)
    assert function_exported?(Multipart.Part, :file_content_field, 5)
  end
end

defmodule Huddlz.Accounts.PasswordAuthenticationTest do
  use Huddlz.DataCase

  alias Ash.Resource.Info
  alias Huddlz.Accounts.User

  describe "password authentication" do
    test "user resource has hashed_password attribute" do
      assert :hashed_password in (User |> Info.attributes() |> Enum.map(& &1.name))
    end

    test "user resource has confirmed_at attribute" do
      assert :confirmed_at in (User |> Info.attributes() |> Enum.map(& &1.name))
    end

    test "register_with_password action exists" do
      assert :register_with_password in (User
                                         |> Info.actions()
                                         |> Enum.map(& &1.name))
    end

    test "sign_in_with_password action exists" do
      assert :sign_in_with_password in (User
                                        |> Info.actions()
                                        |> Enum.map(& &1.name))
    end

    test "change_password action exists" do
      assert :change_password in (User |> Info.actions() |> Enum.map(& &1.name))
    end

    test "request_password_reset_token action exists" do
      assert :request_password_reset_token in (User
                                               |> Info.actions()
                                               |> Enum.map(& &1.name))
    end

    test "reset_password_with_token action exists" do
      assert :reset_password_with_token in (User
                                            |> Info.actions()
                                            |> Enum.map(& &1.name))
    end
  end
end

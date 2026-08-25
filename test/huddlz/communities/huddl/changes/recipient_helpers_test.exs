defmodule Huddlz.Communities.Huddl.Changes.RecipientHelpersTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers
  alias Huddlz.Generator
  alias Huddlz.Notifications

  describe "deliver_each/4" do
    test "adds the recipient's resolved time zone to the payload" do
      recipient = Generator.user(time_zone_preference: nil) |> Generator.generate()
      huddl = Generator.huddl(time_zone: "America/Chicago") |> Generator.generate()

      assert :ok =
               RecipientHelpers.deliver_each(
                 [recipient.id],
                 :huddl_new,
                 %{
                   "huddl_id" => huddl.id,
                   "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at)
                 },
                 huddl
               )

      assert {:ok, %{results: [notification]}} =
               Notifications.list_for_user(actor: recipient, page: [limit: 10])

      assert notification.payload["time_zone"] == "America/Chicago"
    end

    test "prefers the recipient's own time zone preference over the huddl's" do
      recipient =
        Generator.user(time_zone_preference: "America/Denver") |> Generator.generate()

      huddl = Generator.huddl(time_zone: "America/Chicago") |> Generator.generate()

      RecipientHelpers.deliver_each(
        [recipient.id],
        :huddl_new,
        %{"huddl_id" => huddl.id, "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at)},
        huddl
      )

      assert {:ok, %{results: [notification]}} =
               Notifications.list_for_user(actor: recipient, page: [limit: 10])

      assert notification.payload["time_zone"] == "America/Denver"
    end
  end
end

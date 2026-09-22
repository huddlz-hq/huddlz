defmodule Huddlz.Communities.SocialConnection.Validations.PlatformWebhook do
  @moduledoc "Only the selected platform's HTTPS webhook endpoints may receive posts."
  use Ash.Resource.Validation

  alias Huddlz.Communities.SocialConnection.EncryptedString
  alias Huddlz.Social.Webhook

  @impl true
  def validate(changeset, _opts, _context) do
    kind = Ash.Changeset.get_attribute(changeset, :kind)

    url =
      changeset
      |> Ash.Changeset.get_attribute(:webhook_url)
      |> EncryptedString.reveal()

    if Webhook.valid?(kind, url) do
      :ok
    else
      {:error,
       field: :webhook_url, message: "must be a webhook address from the selected platform"}
    end
  end
end

defmodule Huddlz.Vault do
  @moduledoc """
  Encrypts the few secrets huddlz stores on behalf of others, such as the
  webhook address a social connection posts through. AES-256-GCM with a
  key derived from the endpoint's secret key base, so no new secret is
  needed and rotating the base invalidates every stored value at once.
  """

  @aad "huddlz.vault"
  @iv_bytes 12
  @tag_bytes 16

  @doc "The value encrypted, as text safe to store in a column."
  @spec encrypt(String.t()) :: String.t()
  def encrypt(plain) when is_binary(plain) do
    iv = :crypto.strong_rand_bytes(@iv_bytes)
    {cipher, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key(), iv, plain, @aad, true)
    Base.url_encode64(iv <> tag <> cipher, padding: false)
  end

  @doc "The plain value, or `:error` when the text was not produced by `encrypt/1` under this key."
  @spec decrypt(String.t()) :: {:ok, String.t()} | :error
  def decrypt(stored) when is_binary(stored) do
    with {:ok, <<iv::binary-size(@iv_bytes), tag::binary-size(@tag_bytes), cipher::binary>>} <-
           Base.url_decode64(stored, padding: false),
         plain when is_binary(plain) <-
           :crypto.crypto_one_time_aead(:aes_256_gcm, key(), iv, cipher, @aad, tag, false) do
      {:ok, plain}
    else
      _ -> :error
    end
  end

  defp key do
    base = Application.fetch_env!(:huddlz, HuddlzWeb.Endpoint)[:secret_key_base]
    :crypto.hash(:sha256, "vault:" <> base)
  end
end

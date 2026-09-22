defmodule Huddlz.Social.Provider do
  @moduledoc """
  What a platform must offer for a group to connect a place on it: a
  consent screen that picks the channel, and an exchange that turns the
  code it hands back into a webhook for that channel.
  """

  @callback authorize_url(config :: keyword(), state :: String.t(), redirect_uri :: String.t()) ::
              String.t()

  @callback exchange(
              config :: keyword(),
              code :: String.t(),
              redirect_uri :: String.t(),
              req_options :: keyword()
            ) :: {:ok, Huddlz.Social.place()} | {:error, term()}
end

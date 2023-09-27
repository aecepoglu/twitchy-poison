defmodule Twitch.Auth do
  use GenServer

  def get(), do: GenServer.call(:twitch_auth, :get, 60000)
  def reset(), do: GenServer.call(:twitch_auth, :reset)

  @impl true
  def init(nil) do
    {:ok, nil}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @impl true
  def handle_call(:get, _, nil) do
    {:ok, token} = OAuthServer.whatever()
    {:reply, token, token}
  end
  def handle_call(:get, _, x), do: {:reply, x, x,}
  def handle_call(:reset, from, _), do: handle_call(:get, from, nil)
end

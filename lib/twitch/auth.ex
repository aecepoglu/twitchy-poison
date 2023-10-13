defmodule Twitch.Auth do
  use GenServer

  def get(), do: GenServer.call(__MODULE__, :get, 60000)
  def reset(), do: GenServer.call(__MODULE__, :reset)

  @impl true
  def init(nil) do
    {:ok, nil}
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def handle_call(:get, _, nil) do
    {:ok, token} = OAuthServer.whatever()
    {:reply, token, token}
  end
  def handle_call(:get, _, x), do: {:reply, x, x,}
  def handle_call(:reset, from, _), do: handle_call(:get, from, nil)
end

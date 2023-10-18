defmodule IRC do
  @twitch_default_rooms ["whimsicallymade"]

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def list_users(ch, room) do
    {:ok, pid} = GenServer.call(IRC.RoomRegistry, {:fetch, {ch, room}})
    list = GenServer.call(pid, :list_users)
    {:ok, list}
  end

  def log_user(ch, room, user) do
    {:ok, pid} = GenServer.call(IRC.RoomRegistry, {:fetch, {ch, room}})
    msgs = GenServer.call(pid, {:log_user, user})
    {:ok, msgs}
  end

  def get(ch) do
    case Registry.lookup(Registry.IRC, ch) do
      [{pid, _}] -> pid
      _          -> nil
    end
  end

  def connect("twitch"=ch) do
    child_spec = %{
      id: Twitch.IrcClient,
      start: {Twitch.IrcClient, :start_link, [ch, [name: via(ch)]]},
    }
    {:ok, pid} = DynamicSupervisor.start_child(IRC.Supervisor, child_spec)
    :ok = Enum.each(@twitch_default_rooms, fn room ->
        WebSockex.send_frame(pid, {:text, "JOIN #" <> room})
      end)
  end

  def disconnect(ch) do
    ch
    |> get
    |> Process.exit(:normal)
  end

  def join(ch, room) do
    ch
    |> via
    |> WebSockex.send_frame({:text, "JOIN #" <> room})
  end

  def part(ch, room) do
    ch
    |> via
    |> WebSockex.send_frame({:text, "PART #" <> room})
  end

  defp via(name) do
    {:via, Registry, {Registry.IRC, name}}
  end
end

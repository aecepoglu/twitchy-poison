defmodule IRC do
  @twitch_default_rooms ["whimsicallymade"]

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def create_room(ch, room) do
    spec = %{
        id: IRC.Room,
        start: {IRC.Room, :start_link, [room, [name: via({ch, room})]]}
    }
    DynamicSupervisor.start_child(IRC.Supervisor, spec)
  end

  def list_users(ch, room) do
    list = {ch, room}
    |> IRC.via
    |> IRC.Room.users

    {:ok, list}
  end

  def list_rooms() do
    [] # TODO removed feature
  end

  def stats(ch, room) do
    now = Time.utc_now()

    lines = {ch, room}
    |> via
    |> IRC.Room.users
    |> Map.to_list
    |> Enum.map(fn {user, {n, t}} -> {user, n, t} end)
    |> Enum.sort_by(&elem(&1, 2), Time)
    |> Enum.map(fn {user, n, t} -> "#{user}\t#{n}\t#{Time.diff(now, t)/60 + 1 |> floor}" end)

    {:ok, lines}
  end

  def log_user(ch, room, user) do
    msgs = {ch, room}
    |> IRC.via
    |> IRC.Room.log_user(user)

    {:ok, msgs}
  end

  def fetch(id) do
    case Registry.lookup(Registry.IRC, id) do
      [{pid, _}] -> pid
      _          -> nil
    end
  end
  def get(x), do: fetch(x) # TODO get rid of this

  def connect("twitch"=ch) do
    create_room(ch, "-")

    child_spec = %{
      id: Twitch.IrcClient,
      start: {Twitch.IrcClient, :start_link, [ch, [name: via(ch)]]},
    }
    {:ok, _} = DynamicSupervisor.start_child(IRC.Supervisor, child_spec)

    @twitch_default_rooms
    |> Enum.map(&join(ch, &1))
    
    Enum.each(@twitch_default_rooms, &join(ch, &1))
  end

  def disconnect(ch) do
    ch
    |> get
    |> Process.exit(:normal)
  end

  def join(ch, room) do
    create_room(ch, room)
    send_frame(ch, "JOIN #" <> room)
  end

  def part(ch, room) do
    send_frame(ch, "PART #" <> room)
  end

  def text(ch, room, msg) do
    send_frame(ch, "PRIVMSG ##{room} :#{msg}\r\n")
  end

  def send_frame(ch, msg) do
    ch
    |> via
    |> WebSockex.send_frame({:text, msg})
  end

  def via(name) do
    {:via, Registry, {Registry.IRC, name}}
  end
end

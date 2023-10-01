defmodule IRC do
  use GenServer

  @twitch_default_rooms ["whimsicallymade"]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def connect(:twitch), do: GenServer.cast(:irc_hub, {:connect, :twitch})
  def disconnect(:twitch), do: GenServer.cast(:irc_hub, {:disconnect, :twitch})
  def join(:twitch, room), do: GenServer.cast(:irc_hub, {:join, :twitch, room})
  def part(:twitch, room), do: GenServer.cast(:irc_hub, {:part, :twitch, room})
  def list_users(:twitch, room) do
    {:ok, pid} = GenServer.call(:rooms, {:fetch, {"twitch", "#"<>room}})
    list = GenServer.call(pid, :list_users)
    {:ok, list}
  end
  def log_user(:twitch, room, user) do
    {:ok, pid} = GenServer.call(:rooms, {:fetch, {"twitch", "#"<>room}})
    msgs = GenServer.call(pid, {:log_user, user})
    {:ok, msgs}
  end
  def get(addr), do: GenServer.call(:irc_hub, {:get, addr})

  @impl true
  def init(nil) do
    {:ok, {%{}, %{}}}
  end

  @impl true
  def handle_info(msg, state) do
    IO.inspect(msg)
    state
  end

  @impl true
  def handle_cast({:connect, :twitch=addr}, {pids, refs}) do
    {:ok, pid} = DynamicSupervisor.start_child(IRC.Supervisor, Twitch.IrcClient)
    ref = Process.monitor(pid)
    :ok = Enum.each(@twitch_default_rooms, fn room ->
      :ok = WebSockex.send_frame(pid, {:text, "JOIN #" <> room})
      end)
    {:noreply, {Map.put(pids, addr, pid),
                Map.put(refs, pid, ref)}}
  end

  def handle_cast({:disconnect, addr}, {pids, refs}) do
    {:ok, pid} = Map.fetch(pids, addr)
    {:ok, ref} = Map.fetch(refs, pid)
    true = Process.demonitor(ref)
    true = Process.exit(pid, :normal)
    {:noreply, {Map.delete(pids, addr),
                Map.delete(refs, pid)}}
  end

  def handle_cast({:join, addr, room}, {pids, _}=state) do
    {:ok, pid} = Map.fetch(pids, addr)
    :ok = WebSockex.send_frame(pid, {:text, "JOIN #" <> room})
    {:noreply, state}
  end

  def handle_cast({:part, addr, room}, {pids, _}=state) do
    {:ok, pid} = Map.fetch(pids, addr)
    :ok = WebSockex.send_frame(pid, {:text, "PART #" <> room})
    {:noreply, state}
  end

  @impl true
  def handle_call({:get, :twitch=addr}, _from, {pids, _}=state) do
    {:reply, Map.fetch(pids, addr), state}
  end
end

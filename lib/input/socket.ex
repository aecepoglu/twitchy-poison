defmodule IRC do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def connect(:twitch), do: GenServer.cast(:irc_hub, {:connect, :twitch})
  def disconnect(:twitch), do: GenServer.cast(:irc_hub, {:disconnect, :twitch})
  def join(:twitch, room), do: GenServer.cast(:irc_hub, {:join, :twitch, room})
  def part(:twitch, room), do: GenServer.cast(:irc_hub, {:part, :twitch, room})
  def get(addr), do: GenServer.call(:irc_hub, {:get, addr})
  #TODO crash the child process and handle its restart

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
    {:noreply, {Map.put(pids, addr, pid),
                Map.put(refs, addr, ref)}}
  end

  def handle_cast({:disconnect, addr}, {pids, refs}) do
    {:ok, pid} = Map.fetch(pids, addr)
    {:ok, ref} = Map.fetch(refs, addr)
    true = Process.demonitor(ref)
    true = Process.exit(pid, :normal)
    {:noreply, {Map.delete(pids, addr),
                Map.delete(refs, addr)}}
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

defmodule Input.Socket do
  require Logger

  def listen(filepath, :filepath, rmfile: true) do
    if File.exists?(filepath) do
      File.rm!(filepath)
    end
    opts = [:binary,
            ifaddr: {:local, filepath},
            packet: :line,
            active: false,
            reuseaddr: true
            ]
    {:ok, socket} = :gen_tcp.listen(0, opts)
    accept_forever({:ok, socket})
  end

  def listen(port, :port) do
    opts = [:binary,
            packet: :line,
            active: false,
            reuseaddr: true
            ]
    {:ok, socket} = :gen_tcp.listen(port, opts)
    accept_forever({:ok, socket})
  end

  def accept_forever({:ok, socket}) do
    Logger.info("Accepting connections on TODO")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Input.Socket.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    read_request([], socket)
    |> handle
    |> respond(socket)
    serve(socket)
  end

  defp read_request(lines, sock) do
    case read_line(sock) |> trim do
      {:ok, "... " <> line} -> read_request([line | lines], sock)
      {:ok, line}           -> {:ok, Enum.reverse([line | lines])}
      err                   -> err
    end
  end
  defp trim({:ok, str}), do: {:ok, String.trim_trailing(str)}
  defp trim(err),        do: err

  defp handle({:ok, req}) do
    case process(req) do
      :ok -> {:ok, []}
      x   -> x
    end
  end
  defp handle({:error, _}=err),    do: err

  defp process(["quit"]),          do: :init.stop()
  defp process(["done"]),          do: Hub.task_done()
  defp process(["push " <> x]),    do: Hub.task_add(x, :push)
  defp process(["insert " <> x]),  do: Hub.task_add(x, :last)
  defp process(["next " <> x]),    do: Hub.task_add(x, :next)
  defp process(["pop"]),           do: cast(:task_pop)
  defp process(["del"]),           do: Hub.task_del()
  defp process(["rot in"]),        do: Hub.task_rot(:inside)
  defp process(["rot out"]),       do: Hub.task_rot(:outside)
  defp process(["join"]),          do: Hub.task_join()
  defp process(["join eager"]),    do: Hub.task_join_eager()
  defp process(["disband"]),       do: Hub.task_disband()
  defp process(["curtask"]),       do: Hub.get_cur_task()
  defp process(["puthead" | x]),   do: Hub.put_cur_task(x)
  defp process(["putchores" | x]), do: Hub.put_chores(x)
  defp process(["task persist"]),  do: cast(:task_persist)
  defp process(["debug"]),         do: cast(:debug)
  defp process(["hello"]),         do: {:ok, ["world"]}
  defp process(["sum" | nums]),    do: {:ok, [nums
                                              |> Enum.map(&String.to_integer/1)
                                              |> Enum.reduce(0, & &1 + &2)
                                              |> to_string
                                              ]}
  defp process(["irc /connect twitch"]), do: IRC.connect(:twitch)
  defp process(["irc /disconnect twitch"]), do: IRC.disconnect(:twitch)
  defp process(["irc /join twitch " <> room]), do: IRC.join(:twitch, room)
  defp process(["irc /part twitch " <> room]), do: IRC.part(:twitch, room)
  defp process(["irc /switch  " <> _room]), do: {:ok, "TODO"}
  defp process([_]),               do: {:error, :unknown_command}

  defp cast(msg), do: GenServer.cast(:hub, msg)

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp respond({:error, :closed}, _) do
    Process.sleep(100)
    exit(:shutdown) # TODO causes inconsistency in returns
  end
  defp respond({:error, :unknown_command}, socket) do
    :gen_tcp.send(socket, "unknown cmd. Try incr or decr\n")
  end
  defp respond({:error, err}, socket) do
    :gen_tcp.send(socket, "err\n")
    exit(err)
  end
  defp respond({:ok, []}, socket), do: respond({:ok, ["ok."]}, socket)
  defp respond({:ok, reply}, socket) do
    str = Enum.join(reply, "\n")
    :gen_tcp.send(socket, str <> "\r\n")
  end
end

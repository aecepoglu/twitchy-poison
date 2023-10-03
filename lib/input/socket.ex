defmodule Input.Socket.Message do
  def parse(str) when is_binary(str) do
    String.split(str, " ")
    |> identify
  end
  defp identify(["irc", "connect", ch]), do: {:irc, :connect, ch}
  defp identify(["irc", "disconnect", ch]), do: {:irc, :disconnect, ch}
  defp identify(["irc", "join", ch, room]), do: {:irc, :join, ch, room}
  defp identify(["irc", "part", ch, room]), do: {:irc, :part, ch, room}
  defp identify(["irc", "users", ch, room]), do: {:irc, :users, ch, room}
  defp identify(["irc", "log", ch, room, user]), do: {:irc, :log, ch, room, user}
end
defmodule Input.Socket do
  require Logger
  alias Input.Socket.Message, as: Message

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

  defp process(["done"]),          do: cast([:task, :done])
  defp process(["push " <> x]),    do: cast([:task, :add, x, :push])
  defp process(["insert " <> x]),  do: cast([:task, :add, x, :last])
  defp process(["next " <> x]),    do: cast([:task, :add, x, :next])
  defp process(["pop"]),           do: cast([:task, :pop])
  defp process(["del"]),           do: cast([:task, :del])
  defp process(["rot in"]),        do: cast([:task, :rot, :inside])
  defp process(["rot out"]),       do: cast([:task, :rot, :outside])
  defp process(["join"]),          do: cast([:task, :join])
  defp process(["join eager"]),    do: cast([:task, :join_eager])
  defp process(["disband"]),       do: cast([:task, :disband])
  defp process(["puthead" | x]),   do: cast([:task, :put_cur, x])
  defp process(["quit"]),          do: :init.stop()
  defp process(["curtask"]),       do: Hub.get_cur_task()
  defp process(["putchores" | x]), do: Hub.put_chores(x)
  defp process(["debug"]),         do: cast(:debug)
  defp process(["hello"]),         do: {:ok, ["world"]}
  defp process(["refresh"]),       do: cast(:refresh)
  defp process(["sum" | nums]),    do: {:ok, [nums
                                              |> Enum.map(&String.to_integer/1)
                                              |> Enum.reduce(0, & &1 + &2)
                                              |> to_string
                                              ]}
  defp process(["auto-update yes"]), do: cast({:auto_update, true})
  defp process(["auto-update no"]),  do: cast({:auto_update, false})
  defp process(["restart socket"]), do: {:error, :restart_socket}
  defp process(["rewind " <> n]), do: cast({:rewind, String.to_integer(n)})
  defp process([h|_]), do: process(Message.parse(h))
  defp process({:irc, :connect, "twitch"}), do: IRC.connect(:twitch)
  defp process({:irc, :disconnect, "twitch"}), do: IRC.disconnect(:twitch)
  defp process({:irc, :join, "twitch", room}), do: IRC.join(:twitch, room)
  defp process({:irc, :part, "twitch", room}), do: IRC.part(:twitch, room)
  defp process({:irc, :users, "twitch", room}), do: IRC.list_users(:twitch, room)
  defp process({:irc, :log, "twitch", room, user}), do: IRC.log_user(:twitch, room, user)
  defp process([]),               do: {:error, :unknown_command}

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
  defp respond({:error, :restart_socket}, socket) do
    :gen_tcp.send(socket, "restarting socket\n")
    exit(:restart_socket)
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

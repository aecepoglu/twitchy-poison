defmodule Input.Socket.Message do
  def parse([line | lines]) do
    [String.split(line, " ") | lines]
    |> identify
  end
  def parse(line) when is_binary(line) do
    String.split(line, " ")
    |> identify
  end
  defp identify(["irc", "connect", ch]), do: {:irc, :connect, ch}
  defp identify(["irc", "disconnect", ch]), do: {:irc, :disconnect, ch}
  defp identify(["irc", "join", ch, room]), do: {:irc, :join, ch, room}
  defp identify(["irc", "part", ch, room]), do: {:irc, :part, ch, room}
  defp identify(["irc", "switch", ch, room]), do: {:irc, :switch, ch, room}
  defp identify(["irc", "users", ch, room]), do: {:irc, :users, ch, room}
  defp identify(["irc", "log", ch, room, user]), do: {:irc, :log, ch, room, user}
  defp identify(["irc", "stats", ch, room]), do: {:irc, :stats, ch, room}
  defp identify(["irc", "chat", ch, room | words]), do: {:irc, :chat, ch, room, Enum.join(words, " ")}
  defp identify(["irc", "list"]), do: {:irc, :list}
  defp identify(["key", k]), do: {:keypress, k}
  defp identify(["mode", mode]) when mode in ["work", "break", "chat"], do: {:mode, String.to_existing_atom(mode)}
  defp identify(["option", k, v]), do: {:option, k, v}
  defp identify(["option", k]), do: {:option, k}
  defp identify(["summary"]), do: :summary
  defp identify(["progress", "small"]), do: {:progress, :small}
  defp identify(["progress", "big"]), do: {:progress, :big}
  defp identify([["chores", "put"] | lines]) do
    chores = lines |> Chore.deserialise |> Chore.sort
    {:chores, :put, chores}
  end
  defp identify(["chores", "get"]), do: {:chores, :get}
  defp identify(["chores", "remove", n]), do: {:chores, :remove, String.to_integer(n)}
  defp identify(["goal", "set" | words]), do: {:goal, :set, Enum.join(words, " ")}
  defp identify(["goal", "envelop"]), do: {:goal, :envelop}
  defp identify(["goal", "unset"]), do: {:goal, :unset}
  defp identify(["suggest", "break-length"]), do: {:suggest, :break_length}
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
  defp process(["restart socket"]),  do: {:error, :restart_socket}
  defp process(["rewind"]),          do: cast(:rewind)
  defp process([line]),      do: line  |> Message.parse |> process_parsed
  defp process([_|_]=lines), do: lines |> Message.parse |> process_parsed

  defp process_parsed({:irc, :connect, ch}), do: IRC.connect(ch)
  defp process_parsed({:irc, :disconnect, ch}), do: IRC.disconnect(ch)
  defp process_parsed({:irc, :join, ch, room}), do: IRC.join(ch, room)
  defp process_parsed({:irc, :part, ch, room}), do: IRC.part(ch, room)
  defp process_parsed({:irc, :users, ch, room}), do: IRC.list_users(ch, room)
  defp process_parsed({:irc, :stats, ch, room}), do: IRC.stats(ch, room)
  defp process_parsed({:irc, :switch, ch, room}), do: cast({:focus_chat, ch, room})
  defp process_parsed({:irc, :log, ch, room, user}), do: IRC.log_user(ch, room, user)
  defp process_parsed({:irc, :chat, ch, room, msg}), do: IRC.text(ch, room, msg)
  defp process_parsed({:irc, :list}) do
    reply = IRC.list_rooms()
            |> Enum.map(fn {a, b} -> a <> " " <> b end)
    {:ok, reply}
  end
  defp process_parsed({:chores, :get}),         do: call(:chores)
  defp process_parsed({:chores, :put, chores}), do: cast({:chores, :put, chores})
  defp process_parsed({:chores, :remove, i}), do: cast({:chores, :remove, i})
  defp process_parsed({:option, _k, _v}=x), do: cast(x)
  defp process_parsed({:option, _k}=x), do: call(x)
  defp process_parsed({:goal, :set, _}=x), do: cast(x)
  defp process_parsed({:goal, :unset}=x), do: cast(x)
  defp process_parsed({:goal, :envelop}=x), do: cast(x)
  defp process_parsed({:suggest, :break_length}=x), do: call(x)
  defp process_parsed({:progress, _}=x), do: cast(x)
  defp process_parsed({:mode, :chat}=x), do: cast(x)
  defp process_parsed({:mode, :break}=x), do: cast(x)
  defp process_parsed({:keypress, k}) do
    Input.Keyboard.report(k)
    :ok
  end
  defp process_parsed(:summary = x), do: call(x)
  
  defp cast(msg), do: Hub.cast(msg)
  defp call(msg), do: Hub.call(msg)

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

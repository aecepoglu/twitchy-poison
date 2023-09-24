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

defmodule Input.Socket.Request do
  def new(), do: {:incomplete, []}

  def grow({:incomplete, lines}, {:ok, "???\n"}) do
    {:complete, :question, Enum.reverse(lines)}
  end
  def grow({:incomplete, lines}, {:ok, data}) do
    {:incomplete, [String.trim_trailing(data) | lines]}
  end
  def grow({:incomplete, lines}, {:error, :closed}) do
    {:complete, :command, Enum.reverse(lines)}
  end
  def grow(_, {:error,_}=err), do: err
end

defmodule Input.Socket do
  require Logger
  alias Input.Socket.Request, as: Request

  def accept(filepath) do
    if File.exists?(filepath) do
      File.rm!(filepath)
    end

    opts =[:binary,
           ifaddr: {:local, filepath},
           packet: :line,
           active: false,
           reuseaddr: true]
    {:ok, socket} = :gen_tcp.listen(0, opts)
    Logger.info("Accepting connections on #{filepath}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Input.Socket.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    read_request(Request.new(), socket)
    |> handle
    |> respond(socket)
    serve(socket)
  end

  defp read_request({:incomplete, _}=req, sock) do
    Request.grow(req, read_line(sock))
    |> read_request(sock)
  end
  defp read_request({:complete, typ, r}, _), do: {:ok, typ, r}
  defp read_request({:error, _}=err    , _), do: err

  defp handle({:ok, typ, req}) do
    case handle(req) do
      {:error, _} = err -> err
      {:ok, res} -> {:ok, typ, res}
      :ok -> {:ok, typ, "no response"}
    end
  end
  defp handle(["quit"]),          do: :init.stop()
  defp handle(["done"]),          do: Hub.task_done()
  defp handle(["pushout " <> x]), do: Hub.task_add(x, :push_out)
  defp handle(["pushin " <> x]),  do: Hub.task_add(x, :push_in)
  defp handle(["insert " <> x]),  do: Hub.task_add(x, :last)
  defp handle(["del"]),           do: Hub.task_del()
  defp handle(["rot in"]),        do: Hub.task_rot(:inside)
  defp handle(["rot out"]),       do: Hub.task_rot(:outside)
  defp handle(["join"]),          do: Hub.task_join()
  defp handle(["join eager"]),    do: Hub.task_join_eager()
  defp handle(["disband"]),       do: Hub.task_disband()
  defp handle(["curtask"]),       do: Hub.get_cur_task()
  defp handle(["hello"]),         do: {:ok, ["world"]}
  defp handle(["puthead" | x]),   do: Hub.put_cur_task(x)
  defp handle(["putchores" | x]), do: Hub.put_chores(x)
  defp handle([_]),             do: {:error, :unknown_command}

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
  defp respond({:ok, :command, _}, socket) do
    respond({:error, :closed}, socket)
    # respond({:ok, :question, ["ok."]}, socket)
  end
  defp respond({:ok, :question, []}, socket), do: respond({:ok, :question, ["(no lines in response)"]}, socket)
  defp respond({:ok, :question, reply}, socket) do
    str = reply
    |> Enum.map(& &1 <> "\n")
    |> Enum.join
    :gen_tcp.send(socket, str)
  end
end

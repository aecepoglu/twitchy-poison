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
  defp handle(["quit"]),        do: :init.stop()
  defp handle(["done"]),        do: TwitchyPoison.task_done()
  defp handle(["add " <> x]),   do: TwitchyPoison.task_add(x)
  defp handle(["del"]),         do: TwitchyPoison.task_del()
  defp handle(["rot"]),         do: TwitchyPoison.task_rot()
  defp handle(["join"]),        do: TwitchyPoison.task_join()
  defp handle(["disband"]),     do: TwitchyPoison.task_disband()
  defp handle(["curtask"]),     do: TwitchyPoison.get_cur_task()
  defp handle(["hello"]),       do: {:ok, ["world"]}
  defp handle(["puthead" | x]), do: TwitchyPoison.put_cur_task(x)
  defp handle([_]),             do: {:error, :unknown_command}

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp respond({:ok, :command, _}, socket) do
    # respond({:ok, :question, ["ok."]}, socket)
    respond({:error, :closed}, socket) #TODO stop hiding this in here
  end
  defp respond({:ok, :question, []}, socket), do: respond({:ok, :question, ["(no lines in response)"]}, socket)
  defp respond({:ok, :question, reply}, socket) do
    str = reply
    |> Enum.map(& &1 <> "\n")
    |> Enum.join
    :gen_tcp.send(socket, str)
  end
  defp respond({:error, :unknown_command}, socket) do
    :gen_tcp.send(socket, "unknown cmd. Try incr or decr\n")
  end
  defp respond({:error, :closed}, _socket) do
    Process.sleep(100)
    exit(:shutdown)
  end
  defp respond({:error, err}, socket) do
    :gen_tcp.send(socket, "err\n")
    exit(err)
  end
end

defmodule Input.Socket.Packet do
  def new(), do: {:unfinished, []}

  def add({:ok, "__SEPARATOR__"}, {:unfinished, lines}) do
    {:finished, lines}
  end
  def add({:ok, line}, {:unfinished, lines}) do
    {:unfinished, [line | lines]}
  end
  def add({:error, _}=err, _pkt), do: err

  def data({_, x}), do: x

  def fin?({:finished, _}), do: true
  def fin?(_), do: false
end

defmodule Input.Socket do
  require Logger

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
    msg = case read_line(socket) do
      {:ok, data} -> data |> String.trim |> parse |> process
      {:error, _}=err -> err
    end
    write_line(socket, msg)

    serve(socket)
  end

  defp parse("incr"), do: {:ok, :incr}
  defp parse("decr"), do: {:ok, :decr}
  defp parse(_), do: {:error, :unknown_command}

  defp process({:ok, :incr}) do
    GenServer.cast(:kbd_listener, {:keypress, "a"})
    {:ok, "incr"}
  end
  defp process({:ok, :decr}) do
    GenServer.cast(:kbd_listener, {:keypress, "b"})
    {:ok, "decr"}
  end
  defp process(x), do: x

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end

  defp write_line(socket, {:ok, _}) do
    :gen_tcp.send(socket, "ok.\r\n")
  end
  defp write_line(socket, {:error, :unknown_command}) do
    :gen_tcp.send(socket, "unknown cmd. Try incr or decr\r\n")
  end
  defp write_line(_socket, {:error, :closed}) do
    Process.sleep(100)
    exit(:shutdown)
  end
  defp write_line(socket, {:error, err}) do
    :gen_tcp.send(socket, "err\r\n")
    exit(err)
  end
end

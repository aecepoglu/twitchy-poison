defmodule Goldfish.Chan.Packet do
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

defmodule Goldfish.Chan.Socket do
  require Logger
  alias Goldfish.Chan.Packet, as: Packet

  def accept(filepath) do
    opts =[:binary,
           ifaddr: {:local, filepath},
           packet: :line,
           active: false,
           reuseaddr: true]
    {:ok, socket} = :gen_tcp.listen(0, opts)
    Logger.info("Accepting connections on #{filepath}")
    loop(socket)
  end

  defp loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    case read(Packet.new(), client) do
      {:ok, ["quit"]} -> "finished"
      {:error, _}     -> "error"
      {:ok, lines}    -> IO.inspect lines
                         :gen_tcp.send(socket, Enum.join(lines, "++ \n"))
                         loop(socket)
    end
  end

  defp read_more(pkt, socket) do
    if Packet.fin?(pkt) do
      pkt
      |> Packet.data
    else
      read(pkt, socket)
    end
  end

  defp read(pkt, socket) do
    input = :gen_tcp.recv(socket, 0)
    Logger.debug {"received", input}

    input
    |> Packet.add(pkt)
    |> read_more(socket)
  end
end

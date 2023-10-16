defmodule SocketTest do
  use ExUnit.Case
  ExUnit.Callbacks

  setup do
    :ok = Application.stop(:twitchy_poison)
    :ok = Application.start(:twitchy_poison)
  end

  setup do
    {:ok, sock} = :gen_tcp.connect('localhost', 4444, [:binary, packet: :line, active: false])
    on_exit(:disconnect, fn ->
      :ok = :gen_tcp.close(sock)
      end)
    %{socket: sock}
  end

  test "send a single line msg", %{socket: sock} do
    assert ask("hello\r\n", sock) == "world\r\n"
  end

  test "send a multi-line msg", %{socket: sock} do
    assert ask("... sum\r\n... 1\r\n... 2\r\n3\r\n", sock) == "6\r\n"
  end

  defp ask(msg, sock) do
    :ok = :gen_tcp.send(sock, msg)
    {:ok, data} = :gen_tcp.recv(sock, 0, 1000)
    data
  end
end

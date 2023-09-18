defmodule Input.Keyboard do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl true
  def init(nil) do
    port = Port.open({:spawn, "tty_sl -c -e"}, [:binary, :eof])
    {:ok, port}
  end

  @impl true
  def handle_info({_port, {:data, data}}, state) do
    data
    |> translate
    |> report

    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, _}}, state) do
    report(:i_am_dead)
    {:noreply, state}
  end

  def handle_info(_, state) do
    IO.puts("handling!!!")
    state
  end

  @impl true
  def handle_call(:quit, _from, state) do
    handle_cast(:quit, state)
  end

  @impl true
  def handle_cast(:quit, port) do
    Port.close(port)
    {:stop, "my mom told me so", port}
  end

  defp report(key) do
    case key do
      "t" -> Hub.tick()
      "r" -> Hub.refresh()
      "1" -> Hub.action_1()
      "2" -> Hub.action_2()
      _ -> nil
    end
    key
    # GenServer.cast(:kbd_listener, {:keypress, key})
  end

  defp translate("\d"), do: :backspace
  defp translate("\r"), do: :enter
  defp translate("\t"), do: :tab
  defp translate("\e"), do: :escape
  defp translate("\e[A"), do: :arrow_up
  defp translate("\e[B"), do: :arrow_down
  defp translate("\e[C"), do: :arrow_right
  defp translate("\e[D"), do: :arrow_left
  defp translate("\e[F"), do: :end
  defp translate("\e[H"), do: :home
  defp translate("\e[3~"), do: :delete
  defp translate("\e[5~"), do: :pg_up
  defp translate("\e[6~"), do: :pg_dn
  defp translate(key), do: key
end

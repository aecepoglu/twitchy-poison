defmodule TwitchyPoison do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: :kbd_listener)
  end

  @impl true
  def init(nil) do
    {:ok, 0}
  end

  @impl true
  def handle_cast({:keypress, "a"}, count), do: update(&incr/1, count)
  def handle_cast({:keypress, "b"}, count), do: update(&decr/1, count)
  def handle_cast({:keypress, _}, count), do: update(&Function.identity/1, count)
  # def handle_call({:keypress, "a"}, _from, count), do: update(&incr/1, count)
  #
  defp update(f, state) do
    state_ = f.(state)
    render(state_)
    {:noreply, state_}
  end

  defp incr(x), do: x + 1
  defp decr(x), do: x - 1

  defp render(count) do
    IO.write(" \rcount: #{count}")
    count
  end
end

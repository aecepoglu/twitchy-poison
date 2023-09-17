defmodule Input.TimeTicker do
  use GenServer

  @timeout :timer.seconds(60)

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(state) do
    {:ok, state, @timeout}
  end

  def handle_info(:timeout, nil=state) do
    TwitchyPoison.tick()
    # GenServer.cast(:kbd_listener, {:keypress, "a"})
    {:noreply, state, @timeout}
  end
end

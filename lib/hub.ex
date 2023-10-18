defmodule Hub do
  use GenServer

  @ignore_ticks true

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: :hub)
  end

  @impl true
  def init(nil) do
    {:ok, _tref1} = :timer.send_interval(:timer.seconds(60), :tick_minute)
    {:ok, _tref2} = :timer.send_interval(:timer.seconds(1), :tick_second)
    {:ok, Model.make(create_initial_reminders: true)}
  end

  @impl true
  def handle_cast(event, state) when event in [:tick_minute, :tick_second] and @ignore_ticks do
    Model.update(state, event)
    |> noreply
  end
  def handle_cast(event, state) do
    Model.update(state, event)
    |> tap(&Model.render/1)
    |> noreply
  end

  @impl true
  def handle_call(msg, _from, state) do
    resp = Model.ask(msg, state)
    {:reply, resp, state}
  end

  @impl true
  def handle_info(:tick_minute, state), do: handle_cast(:tick_minute, state)
  def handle_info(:tick_second, state) when state.mode == :break, do: handle_cast(:tick_second, state)
  def handle_info(:tick_second, state), do: {:noreply, state}

  def tick(), do: GenServer.cast(:hub, :tick_minute)
  def task_disband(), do: GenServer.cast(:hub, :task_disband)
  def get_cur_task(), do: GenServer.call(:hub, :task_get_cur)
  def refresh(), do: GenServer.cast(:hub, :refresh)
  def mode(val), do: GenServer.cast(:hub, {:mode, val})
  def start_break(), do: GenServer.cast(:hub, :start_break)
  def dir_move(dir), do: GenServer.cast(:hub, {:dir, dir})
  def escape(), do: GenServer.cast(:hub, :escape)
  def cast(msg), do: GenServer.cast(:hub, msg)
  def call(msg), do: GenServer.call(:hub, msg)

  defp noreply(x), do: {:noreply, x}
end

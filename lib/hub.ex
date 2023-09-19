defmodule Hub do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: :hub)
  end

  @impl true
  def init(nil) do
    {:ok, timer_ref1} = :timer.send_interval(:timer.seconds(60), :tick_minute)
    {:ok, timer_ref2} = :timer.send_interval(:timer.seconds(1), :tick_second)
    {:ok, Model.make()}
  end

  @impl true
  def handle_cast(event, state) do
    Model.update(state, event)
    |> tap(&Model.render/1)
    |> noreply
  end

  @impl true
  def handle_call(:task_get_cur, _from, {_, todo}=state) do
    resp = Todo.dump_cur(todo)
    {:reply, resp, state}
  end

  @impl true
  def handle_info(:tick_minute, state), do: handle_cast(:tick_minute, state)
  def handle_info(:tick_second, state) when state.mode == :break, do: handle_cast(:tick_second, state)
  def handle_info(:tick_second, state), do: {:noreply, state}

  def tick(), do: GenServer.cast(:hub, :tick_minute)
  def task_add(task), do: GenServer.cast(:hub, {:task_add, task})
  def task_done(), do: GenServer.cast(:hub, :task_done)
  def task_disband(), do: GenServer.cast(:hub, :task_disband)
  def task_rot(), do: GenServer.cast(:hub, :task_rot)
  def task_join(), do: GenServer.cast(:hub, :task_join)
  def task_del(), do: GenServer.cast(:hub, :task_del)
  def get_cur_task(), do: GenServer.call(:hub, :task_get_cur)
  def put_cur_task(lines), do: GenServer.cast(:hub, {:task_put_cur, lines})
  def put_chores(lines), do: GenServer.cast(Chore, {:put, lines})
  def action_1(), do: GenServer.cast(:hub, :action_1)
  def action_2(), do: GenServer.cast(:hub, :action_2)
  def refresh(), do: GenServer.cast(:hub, :refresh)
  def mode(val), do: GenServer.cast(:hub, {:mode, val})
  def start_break(), do: GenServer.cast(:hub, :start_break)
  def dir_move(dir), do: GenServer.cast(:hub, {:dir, dir})
  def escape(), do: GenServer.cast(:hub, :escape)

  defp noreply(x), do: {:noreply, x}
end

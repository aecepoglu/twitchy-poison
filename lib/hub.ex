defmodule Hub do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: :hub)
  end

  @impl true
  def init(nil) do
    {:ok, Model.make()}
  end

  @impl true
  def handle_cast(event, state) do
    Model.update(state, event)
    |> render
    |> noreply
  end

  @impl true
  def handle_call(:task_get_cur, _from, {_, todo}=state) do
    resp = Todo.dump_cur(todo)
    {:reply, resp, state}
  end

  def tick(), do: GenServer.cast(:hub, :tick)
  def task_add(task), do: GenServer.cast(:hub, {:task_add, task})
  def task_done(), do: GenServer.cast(:hub, :task_done)
  def task_disband(), do: GenServer.cast(:hub, :task_disband)
  def task_rot(), do: GenServer.cast(:hub, :task_rot)
  def task_join(), do: GenServer.cast(:hub, :task_join)
  def task_del(), do: GenServer.cast(:hub, :task_del)
  def get_cur_task(), do: GenServer.call(:hub, :task_get_cur)
  def put_cur_task(lines), do: GenServer.cast(:hub, {:task_put_cur, lines})
  def action_1(), do: GenServer.cast(:hub, :action_1)
  def action_2(), do: GenServer.cast(:hub, :action_2)
  def refresh(), do: nil

  defp render(%Model{}=m) do
    IO.write(IO.ANSI.clear())
    Hourglass.render(m.hg)
    Alarm.render_tmp(m.alarms)
    IO.puts("\n\r")
    Todo.render(m.todo)
    if m.popup != nil do
      Popup.render(m.popup)
    end
    m
  end

  defp noreply(x), do: {:noreply, x}
end

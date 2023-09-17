defmodule Model do
  defstruct [:hg, :todo, :alarms]

  def make(), do: %__MODULE__{
    hg: Hourglass.make(),
    todo: Todo.empty(),
    alarms: [],
  }

  def update(m, :tick) do
    m
    |> tick(:hg)
    |> tick(:alarms)
    |> add_hourglass_alarms()
  end
  def update(m, {:task_add, task}), do: %Model{m |
    hg: Hourglass.progress(m.hg, 1),
    todo: Todo.add(m.todo, %Todo{label: task}),
    }
  def update(m, :task_done), do: %{m |
    hg: Hourglass.progress(m.hg, 3),
    todo: Todo.mark_done(m.todo),
    }
  def update(m, :task_disband), do: %Model{m |
    hg: Hourglass.progress(m.hg, 1),
    todo: Todo.disband(m.todo),
    }
  def update(m, :task_rot), do: %Model{m |
    hg: Hourglass.progress(m.hg, 1),
    todo: Todo.rot(m.todo),
    }
  def update(m, :task_join), do: %Model{m |
    hg: Hourglass.progress(m.hg, 1),
    todo: Todo.join(m.todo),
    }
  def update(m, :task_del), do: %Model{m |
    hg: Hourglass.progress(m.hg, 1),
    todo: Todo.del(m.todo),
    }
  def update(m, {:task_put_cur, x}), do: %Model{m |
    hg: Hourglass.progress(m.hg, 1),
    todo: Todo.upsert_head(m.todo, Todo.deserialise(x)),
    }

  defp tick(m, :hg), do: %Model{m | hg: Hourglass.tick(m.hg)}
  defp tick(m, :alarms), do: %Model{m | alarms: Alarm.ticks(m.alarms)}
  defp add_hourglass_alarms(m), do: %Model{m | alarms: Hourglass.alerts(m.hg) ++ m.alarms}
end

defmodule TwitchyPoison do
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
  def refresh(), do: nil

  defp render(%Model{}=m) do
    IO.write(IO.ANSI.clear())
    Hourglass.render(m.hg)
    IO.puts("\n\r")
    Todo.render(m.todo)
    m
  end

  defp noreply(x), do: {:noreply, x}
end

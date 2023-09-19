defmodule Model do
  defstruct [:hg,
             :todo,
             :size,
             alarms: [],
             popup: nil,
             mode: :work,
             tmp: nil,
             ]

  def make(), do: %__MODULE__{
      hg: Hourglass.make(),
      todo: Todo.empty() |> Todo.add(%Todo{label: "testing 1 2 3"}),
      size: get_win_size(),
    }

  def update(m, :tick_minute) do
    m
    |> tick(:hg)
    |> tick(:alarms)
    |> add_new_alerts
    |> set_popup(overwrite: false)
  end
  def update(m, :tick_second) when m.mode == :break do
    %{m | tmp: Break.tick(m.tmp)}
  end
  def update(m, {:task_add, task}), do: %{m |
    hg: Hourglass.progress(m.hg, 1),
    todo: Todo.add(m.todo, %Todo{label: task}),
    }
  def update(m, :task_done), do: %{m |
    hg: Hourglass.progress(m.hg, 3),
    todo: Todo.mark_done!(m.todo),
    }
  def update(m, :task_disband), do: %Model{m |
    todo: Todo.disband(m.todo),
    }
  def update(m, :task_rot), do: %Model{m |
    todo: Todo.rot(m.todo),
    }
  def update(m, :task_join), do: %Model{m |
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
  def update(m, :action_1), do: Popup.act(m.popup, :action_1, m)
  def update(m, :action_2), do: %{m | popup: nil}
  def update(m, :refresh), do: %{m | size: get_win_size()}
  def update(m, {:dir, :up}) when m.mode == :breakprep, do: %{m | tmp: Break.make_longer(m.tmp)}
  def update(m, {:dir, :down}) when m.mode == :breakprep, do: %{m | tmp: Break.make_shorter(m.tmp)}
  def update(m, :escape) when m.mode == :breakprep, do: %{m | mode: :work, tmp: nil}
  def update(m, {:dir, _}), do: m

  def update(m, :start_break) when m.mode == :work, do:
    %{m |
      mode: :breakprep,
      tmp: Break.make(Chore.pop())
      }
  def update(m, :start_break) when m.mode == :breakprep, do: %{m | mode: :break}
  def update(m, :start_break) when m.mode == :break, do: %{m | mode: :work}

  defp tick(m, :hg), do: %Model{m | hg: Hourglass.tick(m.hg, m.mode)}
  defp tick(m, :alarms), do: %Model{m | alarms: Alarm.ticks(m.alarms, 1)}

  defp add_new_alerts(m) do
    aa = Hourglass.alerts(m.hg)
    |> Enum.reduce(m.alarms, & Alarm.add(&2, &1))
    %Model{m | alarms: aa}
  end

  def set_popup(%Model{popup: p}=m, overwrite: false) when not(is_nil(p)), do: m
  def set_popup(%Model{        }=m, _) do
    {alarms, popup} = Alarm.popup(m.alarms)
    %Model{m | popup: popup, alarms: alarms}
  end

  def snooze(%Model{}=m) do
    %{m | alarms: Alarm.snooze(m.alarms)}
    |> Model.set_popup(overwrite: true)
  end

  defp get_win_size() do
    {:ok, width} = :io.columns()
    {:ok, height} = :io.rows()
    {width, height}
  end

  def render(%Model{mode: :breakprep}=m) do
    IO.write(IO.ANSI.clear() <> IO.ANSI.cursor(1, 1))
    Break.render(m.tmp, :breakprep, m.size)
  end
  def render(%Model{mode: :break}=m) do
    IO.write(IO.ANSI.clear() <> IO.ANSI.cursor(1, 1))
    Break.render(m.tmp, :break, m.size)
  end
  def render(%Model{mode: :work}=m) do
    IO.write(IO.ANSI.clear() <> IO.ANSI.cursor(1, 1))
    Hourglass.render(m.hg, m.size)
    Alarm.render_tmp(m.alarms, m.size)
    IO.puts("\n\r")
    Todo.render(m.todo, m.size)
    if m.popup != nil do
      Popup.render(m.popup, m.size)
    end
  end
end

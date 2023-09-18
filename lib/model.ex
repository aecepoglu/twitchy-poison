defmodule Model do
  defstruct [:hg, :todo, :alarms, :popup]

  def make(), do: %__MODULE__{
    hg: Hourglass.make(),
    todo: Todo.empty(),
    alarms: [],
    popup: nil,
  }

  def update(m, :tick) do
    m
    |> tick(:hg)
    |> tick(:alarms)
    |> add_new_alerts
    |> set_popup(overwrite: false)
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
  def update(m, :action_1), do: Popup.act(m.popup, :action_1, m)
  def update(m, :action_2), do: %{m | popup: nil}

  defp tick(m, :hg), do: %Model{m | hg: Hourglass.tick(m.hg)}
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
end

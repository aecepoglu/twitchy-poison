defmodule Model do
  defstruct [:hg,
             :todo,
             :size,
             alarms: [],
             popup: nil,
             mode: :work,
             tmp: nil,
             notification?: false
             ]

  def make(), do: %__MODULE__{
      hg: Hourglass.make(),
      todo: Todo.empty(),
      size: get_win_size(),
    }

  def ask(:task_get_cur, m), do: {:ok, Todo.dump_cur(m.todo)}

  def update(m, :tick_minute) do
    m
    |> tick(:hg)
    |> tick(:alarms)
    |> add_new_alerts
    |> set_popup(overwrite: false)
  end
  def update(m, :tick_second) when m.mode == :break, do: %{m | tmp: Break.tick(m.tmp)}
  def update(m, {:received_chat_msg, from}), do: %{m | notification?: from}
  def update(m, :task_reload), do: %{m | todo: GenServer.call(:todo_backup, :get)}
  def update(m, {:task_add, task, pos}), do: %{m |
    hg: Hourglass.progress(m.hg, 2),
    todo: Todo.add(m.todo, %Todo{label: task}, pos),
    }
  def update(m, :task_done), do: %{m |
    hg: Hourglass.progress(m.hg, 10),
    todo: Todo.mark_done!(m.todo),
    }
  def update(m, :task_disband), do: %Model{m | todo: Todo.disband(m.todo)}
  def update(m, {:task_rot, mode}), do: %Model{m | todo: Todo.rot(m.todo, mode)}
  def update(m, :task_join), do: %Model{m | todo: Todo.join(m.todo)}
  def update(m, :task_join_eager), do: %Model{m | todo: Todo.join_eager(m.todo)}
  def update(m, :task_pop), do: %Model{m | todo: Todo.pop(m.todo)}
  def update(m, :task_del), do: %Model{m |
    hg: Hourglass.progress(m.hg, 1),
    todo: Todo.del(m.todo),
    }
  def update(m, {:task_put_cur, x}), do: %Model{m |
    hg: Hourglass.progress(m.hg, 3),
    todo: Todo.upsert_head(m.todo, Todo.deserialise(x)),
    }
  def update(m, :task_persist), do: %{m | todo: Todo.persist!(m.todo)}
  def update(m, action) when action in [:action_1, :action_2, :escape]
                        and m.popup != nil, do: Popup.act(m.popup, action, m)
  def update(m, :refresh), do: %{m | size: get_win_size()}
  def update(m, {:dir, :up}) when m.mode == :breakprep, do: %{m | tmp: Break.make_longer(m.tmp)}
  def update(m, {:dir, :down}) when m.mode == :breakprep, do: %{m | tmp: Break.make_shorter(m.tmp)}
  def update(m, :escape), do: %{m | mode: :work, tmp: nil}
  def update(m, {:dir, _}), do: m

  def update(m, :start_break) when m.mode == :work, do:
    %{m |
      mode: :breakprep,
      tmp: Break.make(FlowState.suggest(m), Chore.pop())
      }
  def update(m, :start_break) when m.mode == :breakprep, do: %{m | mode: :break}
  def update(m, :start_break) when m.mode == :break, do: %{m | mode: :work}

  def update(m, :debug), do: %{m | mode: :debug}

  def update(m, :focus_chat) when m.notification? != nil, do: %{m | mode: :chat}

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
  def set_popup(%Model{}=m), do: set_popup(m, overwrite: false)

  def snooze(%Model{}=m) do
    %{m | alarms: Alarm.snooze(m.alarms)}
    |> Model.set_popup(overwrite: true)
  end

  defp get_win_size() do
    {:ok, width} = :io.columns()
    {:ok, height} = :io.rows()
    {width, height}
  end

  def render(%Model{size: {width, height}}) when width < 30 and height < 3 do
    IO.write(IO.ANSI.clear() <> IO.ANSI.cursor(1, 1))
    IO.write("#{width}x#{height} too small")
  end
  def render(%Model{mode: :debug}=m) do
    IO.write(IO.ANSI.clear() <> IO.ANSI.cursor(1, 1))
    IO.write("DEBUG\n\r")
    {width, height} = m.size
    IO.write("size #{width}x#{height}\n\r")
    IO.write("alarms ")
    Alarm.render_tmp(m.alarms, m.size)
    IO.write("\n\r")
  end
  def render(%Model{mode: :breakprep}=m) do
    IO.write(IO.ANSI.clear() <> IO.ANSI.cursor(1, 1))
    Break.render(m.tmp, :breakprep, m.size)
  end
  def render(%Model{mode: :break}=m) do
    IO.write(IO.ANSI.clear() <> IO.ANSI.cursor(1, 1))
    Break.render(m.tmp, :break, m.size)
  end
  def render(%Model{mode: :work, size: {_, height}}=m) do
    IO.write(IO.ANSI.clear() <> IO.ANSI.cursor(1, 1))
    Hourglass.render(m.hg, m.size)
    IO.write("\n\r")
    Todo.render(m.todo, m.size)
    if m.notification? do
      IO.write(
        IO.ANSI.cursor(height, 1)
        <> IO.ANSI.clear_line()
        <> "TODO show new msg notification here"
      )
    end
    if m.popup != nil do
      Popup.render(m.popup, m.size)
    end
  end
  def render(%Model{mode: :chat}=m) do
    IO.write(IO.ANSI.clear() <> IO.ANSI.cursor(1, 1) <> "chat\n\r")
    {:ok, pid} = IRC.RoomRegistry.get(:rooms, m.notification?)
    GenServer.call(pid, :get)
    |> IRC.Room.render(m.size)
    |> Enum.join("\n\r")
    |> IO.write()
  end
end

defmodule FlowState do
  def suggest(%Model{}=m) do
    Hourglass.past(m.hg)
    |> suggest_break_len()
  end
  def need_break?(%CircBuf{}=past, %CurWin{}=now) do
    (now.broke == 0) && (suggest_break_len(past) > 0)
  end
  def suggest_break_len(%CircBuf{}=past) do
    {work, rest} = Trend.stats(past)
    60 * (floor(work / 3) - rest)
    |> max(0)
  end
end

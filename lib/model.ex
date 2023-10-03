defmodule Model do
  alias Progress.Hourglass, as: Hourglass

  defstruct [:hg,
             :todo,
             :size,
             alarms: [],
             popup: nil,
             mode: :work,
             tmp: nil,
             notification: nil,
             last_notification: nil,
             options: %{
               follow_chat_live?: true,
               split_v?: true,
             },
             ]

  def make() do
    %__MODULE__{
      hg: Backup.get(:hourglass_backup),
      todo: Backup.get(:todo_backup),
      size: get_win_size(),
    }
  end

  def ask(:task_get_cur, m), do: {:ok, Todo.dump_cur(m.todo)}
  def ask(:options, m), do: {:ok, m.options}
  def ask(:progress, m), do: {:ok, m.hg}

  def update(m, :tick_minute) do
    m
    |> tick(:hg)
    |> tick(:alarms)
    |> add_new_alerts
    |> set_popup(overwrite: false)
  end
  def update(m, :tick_second) when m.mode == :break, do: %{m | tmp: Break.tick(m.tmp)}
  def update(m, {:received_chat_msg, from}), do: %{m | notification: from,
                                                       last_notification: from}
  def update(m, {:rewind, n}), do: %{m | hg: Hourglass.rewind(m.hg, n)}
  def update(m, [:task | tl]) do
    {dp, todo_} = task_update(m.todo, tl)
    %{m | todo: todo_ |> Backup.set(:todo_backup),
          hg: Hourglass.progress(m.hg, dp) |> Backup.set(:hourglass_backup)
      }
  end
  def update(m, :task_reload), do: %{m | todo: GenServer.call(:todo_backup, :get)}
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

  def update(m, :focus_chat) when m.notification != nil, do: %{m | mode: :chat}
  def update(m, {:option, key, value}) do
    Map.update!(m, :options, &Map.put(&1, key, value))
  end

  defp tick(m, :hg), do: %Model{m | hg: Hourglass.tick(m.hg, m.mode) |> Backup.set(:hourglass_backup)}
  defp tick(m, :alarms), do: %Model{m | alarms: Alarm.ticks(m.alarms, 1)}

  defp task_update(todo, [:add, task, pos]), do: {1 , Todo.add(todo, %Todo{label: task}, pos)}
  defp task_update(todo, [:done]),           do: {10, Todo.mark_done!(todo)}
  defp task_update(todo, [:disband]),        do: {0 , Todo.disband(todo)}
  defp task_update(todo, [:join]),           do: {0 , Todo.join(todo)}
  defp task_update(todo, [:join_eager]),     do: {0 , Todo.join_eager(todo)}
  defp task_update(todo, [:pop]),            do: {0 , Todo.pop(todo)}
  defp task_update(todo, [:del]),            do: {1 , Todo.del(todo)}
  defp task_update(todo, [:put_cur, x]),     do: {5 , Todo.upsert_head(todo, Todo.deserialise(x))}
  defp task_update(todo, [:rot, mode]),      do: {0 , Todo.rot(todo, mode)}
  defp task_update(todo, [:persist]),        do: {0 , Todo.persist!(todo)}

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
  def render(%Model{mode: :work}=m) do
    IO.write(IO.ANSI.cursor(1, 1) <> IO.ANSI.clear())
    render_work(m, embedded: false)
  end
  def render(%Model{mode: :chat}=m) do
    IO.write(IO.ANSI.cursor(1, 1) <> IO.ANSI.clear())
    {width, height} = m.size
    IO.write(IO.ANSI.cursor(1, 1))
    h_rmd = if m.options.split_v? do
      h_half = floor(height / 2)
      render_work(%Model{m | size: {width, h_half}}, embedded: true)
      IO.write(Geometry.hor_line(width, '═') <> "\n\r")
      h_half + 1
    else
      height
    end
    {:ok, pid} = IRC.RoomRegistry.fetch(:rooms, m.notification)
    {lines, unread}
      = IRC.Room.render_and_read(pid, {width, h_rmd - 1},
                                 indent: " ",
                                 skip_unread: not(m.options.follow_chat_live?)
                                 )
    lines
    |> Enum.join("\n\r")
    |> IO.write()
    IO.write("\n\rremainging unread: #{unread}")
  end

  defp render_work(%Model{size: {_, height}}=m, embedded: embed?) do
    Hourglass.render(m.hg, m.size)
    IO.write("\n\r")
    Todo.render(m.todo, m.size)

    notification = if m.notification && not(embed?) do
      IO.ANSI.clear_line() <> "TODO show new msg notification here"
    else
      ""
    end
    IO.write(IO.ANSI.cursor(height, 1) <> notification)
    if m.popup != nil do
      Popup.render(m.popup, m.size)
    end
  end
end

defmodule FlowState do
  @factor 3

  def suggest(%Model{}=m) do
    Progress.Hourglass.past(m.hg)
    |> suggest_break_len()
  end
  def need_break?(past, %Progress.CurWin{}=now) do
    (now.broke == 0) && (suggest_break_len(past) > 0)
  end
  def suggest_break_len(past) do
    %{break: b, idle: _, work: w} = Progress.Trend.recent_stats(past)
    if b * @factor < w do
      0
    else
      %{break: b, idle: _, work: w} = Progress.Trend.stats(past)
      (floor(w / 3) - b)
      |> then(& &1 * 60)
      |> max(0)
    end
  end
end

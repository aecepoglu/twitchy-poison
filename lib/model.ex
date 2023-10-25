defmodule Model do
  alias Progress.Hourglass, as: Hourglass

  defstruct [:size,
             todo: Todo.empty(),
             hg: Hourglass.make(),
             chores: Chore.empty(),
             popups: [],
             upcoming: Upcoming.empty(),
             mode: :work,
             tmp: nil,
             notification: nil,
             chatroom: nil,
             logs: [],
             options: %{follow_chat_live?: true,
                        split_v?: true,
                        },
             ]

  def make(create_initial_reminders: cir) do
    x = %__MODULE__{
      size: get_win_size(),
    }
    if cir do
      x
      |> add_initial_popups
      |> add_chore_popups
    else
      x
    end
  end

  def log(msg, m) do
    %{m | logs: [msg | m.logs]}
  end

  def ask(:task_get_cur, m), do: {:ok, m.todo |> Todo.dump_cur}
  def ask(:chores, m), do: {:ok, m.chores |> Chore.serialise}
  def ask(:everything, m), do: m
  def ask({:option, k}, m), do: {:ok, Map.get(m.options, k, "undefined")}

  def update(m, :tick_minute) do
    m
    |> tick(:hg)
    |> tick(:upcoming)
    |> popup_from_time_stuff()
    |> popup_from_upcoming()
  end
  def update(m, :tick_second) when m.mode == :break, do: %{m | tmp: Break.tick(m.tmp)}
  def update(m, {:received_chat_msg, from}), do: %{m | notification: from}
  def update(m, {:rewind, n}), do: %{m | hg: Hourglass.rewind(m.hg, n)}
  def update(m, [:task | tl]) do
    {dp, todo_} = task_update(m.todo, tl)
    %{m | todo: todo_,
          hg: Hourglass.progress(m.hg, dp),
          popups: if todo_ > 0 do
                    Popup.List.delete(m.popups, :idle)
                  else
                    m.popups
                  end,
      }
  end

  def update(%Model{popups: [h | _]}=m, update), do: Popup.update(h, update, m)

  def update(m, :refresh), do: %{m | size: get_win_size()}
  def update(m, {:dir, :up}) when m.mode == :breakprep, do: %{m | tmp: Break.make_longer(m.tmp) |> Break.set_chore(m.chores)}
  def update(m, {:dir, :down}) when m.mode == :breakprep, do: %{m | tmp: Break.make_shorter(m.tmp) |> Break.set_chore(m.chores)}
  def update(m, {:dir, :right}) when m.mode == :breakprep do
    chores = m.chores |> Chore.rotate
    %{m | tmp: m.tmp |> Break.set_chore(chores), chores: chores}
  end
  def update(m, :escape), do: %{m | mode: :work, tmp: nil}
  def update(m, {:dir, _}), do: m

  def update(m, :start_break) when m.mode == :work, do:
    %{m |
      mode: :breakprep,
      tmp: Break.make(FlowState.suggest(m))
      }
  def update(m, :start_break) when m.mode == :breakprep, do: %{m | mode: :break}
  def update(m, :start_break) when m.mode == :break, do: %{m | mode: :work}

  def update(m, :debug), do: %{m | mode: :debug}
  def update(m, {:put_chores, x}), do: %{m | chores: x}

  def update(m, :focus_chat) when m.notification != nil, do:
    %{m | mode: :chat, chatroom: m.notification, notification: nil}
  def update(m, {:focus_chat, channel, room}) do
    %{m | mode: :chat, chatroom: {channel, room}}
  end
  def update(m, {:option, key, value}) do
    Map.update!(m, :options, &Map.put(&1, key, value))
  end
  def update(m, _), do: m

  defp tick(m, :hg) do
    mode = if Todo.head_meeting?(m.todo) do :meeting else m.mode end
    %Model{m | hg: Hourglass.tick(m.hg, mode)}
  end
  defp tick(m, :upcoming), do: %Model{m | upcoming: Upcoming.tick(m.upcoming)}

  defp popup_from_time_stuff(m) do
    %{m | popups: FlowState.alarms(m) ++ m.popups}
  end

  defp popup_from_upcoming(m) do
    {upcoming, popups} = Upcoming.popup(m.upcoming)
    %{m | upcoming: upcoming,
          popups: popups ++ m.popups}
  end

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

  defp add_initial_popups(%Model{}=m) do
    if m.todo == Todo.empty() do
      popup = Popup.make(:init_tasks, "Add some tasks.")
      %{m | popups: [popup | m.popups]}
    else
      m
    end
  end

  defp add_chore_popups(%Model{}=m) do
    if m.chores == Chore.empty() do
      popup = Popup.make(:init_chores, "Don't forget to load up your chores.")
      %{m | popups: [popup | m.popups]}
    else
      m
    end
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
    IO.write("size #{Hourglass.duration(m.hg)}\n\r")
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
      h_half
    else
      height
    end
    {:ok, pid} = IRC.RoomRegistry.fetch(m.chatroom)
    {lines, unread}
      = IRC.Room.render_and_read(pid, {width, h_rmd - 1},
                                 indent: " ",
                                 skip_unread: not(m.options.follow_chat_live?)
                                 )
    lines
    |> Enum.join("\n\r")
    |> IO.write()
    IO.write("\n\rremainging unread: #{unread} #{Time.utc_now()}")
  end

  defp render_work(%Model{size: {width, height}}=m, embedded: embed?) do
    if width < 90 do
      Hourglass.render(m.hg, m.size)
    else
      Hourglass.render(m.hg, {60, height})
      <> " " <> Upcoming.render(m.upcoming, {width - 61, height})
    end <> "\n\r" |> IO.write

    Todo.render(m.todo, m.size) |> IO.puts

    notification = if m.notification && not(embed?) do
      IO.ANSI.clear_line() <> "New chat notifications"
      "new chat notifications"
    else
      ""
    end
    IO.write(IO.ANSI.cursor(height, 1) <> notification)
    case m.popups do
      [popup | tl] -> Popup.render(popup, m.size, length(tl))
      _ -> nil
    end
    IO.write(IO.ANSI.cursor(height, 1))
  end
end

defmodule FlowState do
  @factor 3

  def alarms(%Model{}=m) do
    stats = %{break: _, idle: _, work: _} = Progress.Trend.recent_stats(m.hg |> elem(0))
    ids = MapSet.union(Popup.List.ids(m.popups), Upcoming.ids(m.upcoming))

    list_alarms()
    |> Enum.filter(fn {id, pred, _} -> Popup.List.new_id?(ids, id) && pred.(m, stats) end)
    |> Enum.map(fn    {_,  _,    x} -> x end)
  end

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
      |> then(& &1 * 4 * 60) # TODO hardcoded
      |> max(0)
    end
  end

  defp list_alarms() do
    [
      { :idle,
        fn %Model{hg: hg}, _ -> Progress.Hourglass.idle?(hg) end,
        Popup.make(:idle, "split your task", snooze: 5)
        },
      { :rest,
        fn _, s -> s.work >= 10 && s.idle > 1 end,
        Popup.make(:rest, "take a break", snooze: 15)
        },
    ]
  end
end

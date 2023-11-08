defmodule Model do
  alias Progress.Hourglass, as: Hourglass

  defstruct [:size,
             goal: Goal.empty(),
             todo: Todo.empty(),
             hg: Hourglass.make(),
             chores: Chore.empty(),
             popups: [],
             upcoming: Upcoming.empty()
                       |> Upcoming.add(Popup.Known.rest(), 45),
             mode: :work,
             notification: nil,
             chatroom: nil,
             tail_chatroom: 33,
             logs: [],
             options: %{split_v?: true,
                        },
             ]

  def make(create_initial_reminders: cir) do
    x = %__MODULE__{
      size: get_win_size(),
    }
    if cir do add_initial_popups(x) else x end
  end

  def log(msg, m) do
    %{m | logs: [msg | m.logs]}
  end

  def ask(:task_get_cur, m), do: {:ok, m.todo |> Todo.dump_cur}
  def ask(:chores, m), do: {:ok, m.chores |> Chore.serialise}
  def ask(:everything, m), do: m
  def ask({:option, k}, m), do: {:ok, Map.get(m.options, k, "undefined")}

  def update(m, :tick) do
    %{m | hg: Hourglass.tick(m.hg, m.mode),
          upcoming: Upcoming.tick(m.upcoming)
     }
    |> popup_from_time_stuff()
    |> popup_from_upcoming()
  end

  def update(m, {:log, msg}), do: log(msg, m)

  def update(m, {:received_chat_msg, from}), do:
    %{m | notification: from}

  def update(m, {:rewind, n}), do:
    %{m | hg: Hourglass.rewind(m.hg, n)}

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

  def update(m, {:goal, :set, x}), do:
    %{m | goal: Goal.set(m.goal, x)}
  def update(m, {:goal, :unset}), do:
    %{m | goal: Goal.empty()}
  def update(m, {:goal, :envelop}), do:
    %{m | goal: Goal.empty(),
          todo: if Goal.empty?(m.goal) do
                  m.todo
                else
                  Todo.envelop(m.todo, m.goal)
                end}

  def update(m, :refresh), do:
    %{m | size: get_win_size()}

  def update(%Model{popups: [h | _]}=m, update), do:
    Popup.update(h, update, m)

  def update(m, {:mode, :break}), do:
    %{m | mode: :break, upcoming: Upcoming.remove(m.upcoming, :rest)}
  def update(m, {:mode, :work}), do:
    %{m | mode: :work} |> schedule_next_break
  def update(m, {:mode, mode}) when mode in [:meeting], do:
    %{m | mode: mode}

  def update(m, {:key, :space}) when m.mode == :chat, do:
    %{m | tail_chatroom: Util.UnlimitedArithmetic.add(m.tail_chatroom, 1)}
  def update(m, {:key, :escape}) when m.mode == :chat, do:
    %{m | mode: :work}

  def update(m, :debug), do:
    %{m | mode: :debug}

  def update(m, {:chores, :put, x}), do:
    %{m | chores: x}
  def update(m, {:chores, :delete, x}), do:
    %{m | chores: Chore.remove(m.chores, x)}

  def update(m, :focus_chat) when m.notification != nil, do:
    %{m | mode: :chat, chatroom: m.notification, notification: nil}
  def update(m, {:focus_chat, channel, room}), do:
    %{m | mode: :chat, chatroom: {channel, room}}

  def update(m, {:option, "tail", "infinity"}), do:
    %{m | tail_chatroom: :infinity}
  def update(m, {:option, key, value}), do:
    Map.update!(m, :options, &Map.put(&1, key, value))

  def update(m, _), do: m

  defp popup_from_time_stuff(m) do
    popups = m
             |> FlowState.alarms
             |> then(& Popup.List.concat(&1, m.popups))
    %{m | popups: popups}
  end

  defp popup_from_upcoming(m) do
    {upcoming, popups} = Upcoming.popup(m.upcoming, &FlowState.ready_for?(m, &1))
    popups_ = Enum.map(popups, &FlowState.recontextualise(&1, m))
    %{m | upcoming: upcoming,
          popups: Popup.List.concat(m.popups, popups_)}
  end

  defp task_update(todo, [:add, task, pos]), do: {:small, Todo.add(todo, %Todo{label: task}, pos)}
  defp task_update(todo, [:done]),           do: {:big,   Todo.mark_done!(todo)}
  defp task_update(todo, [:disband]),        do: {:none,  Todo.disband(todo)}
  defp task_update(todo, [:join]),           do: {:none,  Todo.join(todo)}
  defp task_update(todo, [:join_eager]),     do: {:none,  Todo.join_eager(todo)}
  defp task_update(todo, [:pop]),            do: {:none,  Todo.pop(todo)}
  defp task_update(todo, [:del]),            do: {:small, Todo.del(todo)}
  defp task_update(todo, [:put_cur, x]),     do: {:small, Todo.upsert_head(todo, Todo.deserialise(x))}
  defp task_update(todo, [:rot, mode]),      do: {:none,  Todo.rot(todo, mode)}
  defp task_update(todo, [:persist]),        do: {:none,  Todo.persist!(todo)}

  defp add_initial_popups(%Model{}=m) do
    popups = [
      if m.todo == Todo.empty() do
        [Popup.make(:init_tasks, "Add some tasks.")]
      else
        []
      end,
      if m.chores == Chore.empty() do
        [Popup.make(:init_chores, "Don't forget to load up your chores.")]
      else
        []
      end
    ] ++ m.popups
    |> Enum.flat_map(& &1)

    %{m | popups: popups}
  end
  defp schedule_next_break(%Model{}=m) do
    delay = FlowState.suggest_next_break(m)
    %{m | upcoming: m.upcoming |> Upcoming.add(Popup.Known.rest(), delay)}
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
  def render(%Model{}=m) do
    m_ = render_contents(m)
    case m.popups do
      [popup | tl] -> Popup.render(popup, m.size, length(tl))
      _ -> ""
    end |> IO.write
    m_
  end

  def render_contents(%Model{mode: :debug}=m) do
    IO.write(IO.ANSI.clear() <> IO.ANSI.cursor(1, 1))
    IO.write("DEBUG\n\r")
    {width, height} = m.size
    IO.write("size #{width}x#{height}\n\r")
    IO.write("size #{Hourglass.duration(m.hg)}\n\r")
  end
  def render_contents(%Model{mode: :work}=m) do
    IO.write(IO.ANSI.cursor(1, 1) <> IO.ANSI.clear())
    render_work(m, embedded: false)
  end
  def render_contents(%Model{mode: :chat}=m) do
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
                                 skip_unread: Util.UnlimitedArithmetic.positive?(m.tail_chatroom)
                                 )
    lines
    |> Enum.join("\n\r")
    |> IO.write()

    tail_indicator = Util.UnlimitedArithmetic.str(m.tail_chatroom)
    IO.write("\n\rrmg: #{unread} @#{Time.utc_now()}, #{tail_indicator}")
    %{m | tail_chatroom: Util.UnlimitedArithmetic.subtract(m.tail_chatroom, 1) }
  end

  defp render_work(%Model{size: {width, height}}=m, embedded: embed?) do
    if width < 90 do
      Hourglass.render(m.hg, {width, height})
    else
      Hourglass.render(m.hg, {60, 1})
      <> " " <> Upcoming.render(m.upcoming, {width - 61, height})
    end <> "\n\r" |> IO.write

    { n_goal, goal_lines} = Goal.render(m.goal, {width, height})
    {_n_todo, todo_lines} = Todo.render(m.todo, {width, height - n_goal - 1})

    goal_lines <> "\n\r"
    <> Geometry.hor_line(width, '+') <> "\n\r"
    <> todo_lines
    |> IO.write

    notification = if m.notification && not(embed?) do
      IO.ANSI.clear_line() <> "New chat notifications"
      "new chat notifications"
    else
      ""
    end
    IO.write(IO.ANSI.cursor(height, 1) <> notification)
  end
end

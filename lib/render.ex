defmodule View do
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
    IO.write("time #{Progress.Hourglass.duration(m.hg)}\n\r")
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
                                 skip_unread: Util.UnlimitedArithmetic.zero?(m.tail_chatroom)
                                 )
    lines
    |> Enum.join("\n\r")
    |> IO.write()

    tail_indicator = Util.UnlimitedArithmetic.str(m.tail_chatroom)
    IO.write("\n\rrmg: #{unread} @#{Time.utc_now()}, #{tail_indicator}")
    %{m | tail_chatroom: Util.UnlimitedArithmetic.subtract(m.tail_chatroom, 1) }
  end
  def render_contents(%Model{mode: _}=m) do
    IO.write(IO.ANSI.cursor(1, 1) <> IO.ANSI.clear())
    render_work(m, embedded: false)
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

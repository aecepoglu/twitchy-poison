defmodule Model.Summary do
  def gen(%Model{}=m) do
    analytics = Progress.Hourglass.past(m.hg)
    |> Progress.Trend.stats
    |> Map.to_list()
    |> Enum.map(fn {k, v} -> "#{k} => #{v}" end)
    duration = Progress.Hourglass.duration(m.hg)

    [
      ["BASICS", "t => #{duration}" | analytics],
      ["CHORES" | Chore.serialise(m.chores)],
      ["TODOS" | Todo.serialise(m.todo)],
    ]
    |> Enum.flat_map(& &1)
    |> Enum.join("\n")
  end
end

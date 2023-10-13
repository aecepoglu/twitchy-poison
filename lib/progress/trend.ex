defmodule Progress.Trend do
  alias Progress.CurWin, as: CurWin

  @bloks [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    |> Enum.with_index(fn x, i -> {i, x} end)
    |> Map.new()
  @mn 8
  # type work = :idle
  #           | :break
  #           | {:work, int()}

  def make(_len), do: []

  def add(trend, %CurWin{done: d, broke: b}) do
    case {d, b} do
      {0, 0} -> [:idle                | trend]
      {w, 0} -> [{:work, min(@mn, w)} | add_(trend, max(w - @mn, 0))]
      {w, _} -> [:break               | add_(trend, max(w - @mn, 0))]
    end
  end
  defp add_(list            , 0), do: list
  defp add_([ :break    | t], x), do: [:break                   | add_(t, x)]
  defp add_([ :idle     | t], x), do: [{:work, min(@mn, x)}     | add_(t, max(x - @mn, 0))]
  defp add_([{:work, w} | t], x), do: [{:work, min(@mn, w + x)} | add_(t, max(x + w - @mn, 0))]
  defp add_([              ], _), do: []

  def rewind(trend, k), do: Enum.drop(trend, k)

  def idle_too_long?(trend) do
    length(trend) >= 4 && trend
    |> Enum.take(4)
    |> Enum.all?(& &1 == :idle)
  end

  def worked_too_long?(trend) do
    length(trend) >= 10 && trend
    |> Enum.take(10)
    |> Enum.all?(& &1 != :idle && &1 != :break)
  end

  def to_list(x), do: x
  def size(x), do: length(x)
  def id(x), do: length(x)

  def string(x, n) do
    Enum.take(x, n)
    |> Enum.map(&str/1)
    |> pad_to(n)
    |> Enum.join("")
    |> String.reverse
  end

  def stats(trend) do
    map = trend
    |> Enum.map(&category/1)
    |> Enum.frequencies()
    Map.merge(%{idle: 0, work: 0, break: 0}, map)
  end

  def recent_stats(trend) do
    recent(trend, [])
    |> stats
  end
  defp recent([h | _], [:break | _]=acc) when h != :break, do: acc
  defp recent([h | t], acc), do: recent(t, [category(h) | acc])
  defp recent([], acc), do: acc

  defp category({:work, _}), do: :work
  defp category(x),          do: x

  defp str({:work, w}), do: @bloks[w]
  defp str(:break), do: "▀"
  defp str(:idle), do: " "

  defp pad_to(list, n) do
    k = n - length(list) |> max(0)
    pad = Enum.map(1..k, fn _ -> ' ' end)
    list ++ pad
  end
end

defmodule Progress.Trend do
  @bloks [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    |> Enum.with_index(fn x, i -> {i, x} end)
    |> Map.new()
  @mn 8

  def make(), do: {[], {0, 0, 0}}

  def add({trend, acc_win}, win) do
    acc = win |> triple |> sum(acc_win)
    case acc do
      {_, _, 4} -> {[acc | trend], {0, 0, 0}}
      {_, _, _} -> {trend, acc}
    end
  end

  defp triple({:work, :none}), do: {0, 0, 1}
  defp triple({:work, _    }), do: {1, 0, 1}
  defp triple(:break        ), do: {0, 1, 1}

  defp add_(list            , 0), do: list
  defp add_([ :break    | t], x), do: [:break                   | add_(t, x)]
  defp add_([ :idle     | t], x), do: [{:work, min(@mn, x)}     | add_(t, max(x - @mn, 0))]
  defp add_([{:work, w} | t], x), do: [{:work, min(@mn, w + x)} | add_(t, max(x + w - @mn, 0))]
  defp add_([              ], _), do: []

  def rewind(trend, k), do: Enum.drop(trend, k)

  def idle({trend, {0, 0, t0}}) do
    Enum.reduce_while(trend, t0,
      fn {w, b, dt}, t ->
        cond do
          t <= 0    -> {:halt, t + dt}
          w + b > 0 -> {:halt, t + dt - w - b}
          true      -> {:cont, t + dt}
        end
      end)
  end
  def idle(_), do: 0

  def to_list({x, _}), do: x #TODO
  def size({x, _}), do: length(x)
  def id({x, _}), do: length(x)

  def string({x, _, t}, n) do
    k = n - 2
    str = Enum.take(x, k)
    |> Enum.map(&str/1)
    |> pad_to(k)
    |> Enum.join("")
    |> String.reverse
    str <> "[" <> case t do
      0 -> "▝"
      1 -> "▐"
      2 -> "▟"
      3 -> "█"
      _ -> "▚"
    end
  end

  def stats({trend, win}) do
    {work, break, total} = Enum.reduce([win | trend], &sum/2)
    %{work: work, break: break, idle: total - (work + break)}
  end

  def recent_stats({trend, win}) do
    {recent(trend, []), win}
    |> stats
  end
  defp recent([{_, b_w, _} | _], [{_, b_acc, _} | _]=acc) when b_acc > 0 and b_w == 0, do: acc
  defp recent([h | t], acc), do: recent(t, [h | acc])
  defp recent([], acc), do: acc

  defp str({0, 0, _t}), do: " "
  defp str({w, 0, _t}), do: @bloks[w]
  defp str({0, _, _t}), do: "▀"

  defp pad_to(list, n) do
    k = n - length(list) |> max(0)
    pad = Enum.map(1..k, fn _ -> ' ' end)
    list ++ pad
  end

  defp sum({x1, x2, x3}, {y1, y2, y3}), do: {x1 + y1, x2 + y2, x3 + y3}
end

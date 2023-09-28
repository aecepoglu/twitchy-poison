defmodule Progress.Trend do
  alias Progress.CurWin, as: CurWin

  @bloks [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    |> Enum.with_index(fn x, i -> {i, x} end)
    |> Map.new()
  @mn 8

  def make(len) do
    CircBuf.make(len, nil)
  end

  def add(trend, %CurWin{done: d, broke: b}=cw) do
    {CircBuf.add(trend, {min(d, @mn), b}), CurWin.sub(cw, @mn)}
  end

  def idle_too_long?(trend) do
    trend
    |> CircBuf.take(4)
    |> Enum.all?(&idle?/1)
  end

  def worked_too_long?(trend) do
    trend
    |> CircBuf.take(10)
    |> Enum.all?(&active?/1)
  end

  def to_list(x) do
    CircBuf.to_list(x)
  end

  def string(x, n) do
    CircBuf.take(x, n)
    |> Enum.map(&str/1)
    |> Enum.join("")
    |> String.reverse
  end

  def stats(trend) do
    trend
    |> to_list()
    |> Enum.reduce({0, 0}, &sum/2)
  end

  def id(past) do
    CircBuf.count_while(past, & &1 == 0)
  end

  defp idle?({0, 0}), do: true
  defp idle?(_), do: false
  defp active?({_, 0}), do: true
  defp active?(_), do: false

  defp str({w, 0}), do: @bloks[w]
  defp str({_, _}), do: "▀"
  defp str(nil),    do: "-"

  defp sum({a, b}, {c, d}), do: {a + c, b + d}
  defp sum(nil   , x),      do: x
end

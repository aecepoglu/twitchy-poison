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

  def rewind(trend, k) do
    Enum.reduce(1..k, trend, fn _, acc -> CircBuf.remove(acc) end)
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
    # FIXME use frequencies
  end

  def recent_stats(trend) do
    {_, worked, rested} = CircBuf.reduce_while(trend, {:work, 0, 0},
      fn x, {prev, worked, rested} ->
        case {prev, cat(x)} do
          {:break, o} when o != :break -> {o, worked, rested}
          {_, b}  ->
            d_rest = if b == :break do 1 else 0 end
            d_work = if b == :work do 1 else 0 end
            {:continue, {b, worked + d_work, rested + d_rest}}
        end
      end)
    {worked, rested}
  end

  def id(past) do
    CircBuf.count_while(past, & &1 == 0)
  end

  defp cat({0, 0}), do: :idle
  defp cat({_, 0}), do: :work
  defp cat({_, _}), do: :break
  defp cat(nil), do: :none


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

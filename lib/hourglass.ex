defmodule CurWin do
  defstruct [dur: 8,
             val: 0,
             done: 0,
             broke: 0,
            ]

  #def id(%CurWin{done: d}), do: {m, d}

  def make(duration) do
    %__MODULE__{dur: duration}
  end

  defp tick_(%__MODULE__{val: v, dur: k} = me, carry) when v >= k do
    tick_(%{me | val: v - k, done: 0}, [%{me | val: k} | carry])
  end
  defp tick_(%__MODULE__{val: v} = me, carry) do
    {%{me | val: v}, carry |> Enum.reverse}
  end


  def tick(%__MODULE__{} = x, mode, d_val \\ 1) when is_atom(mode) do
    d_broke = if mode != :work do d_val else 0 end
    {_, _} = tick_(
      %{x |
        val: x.val + d_val,
        broke: x.broke + d_broke,
        },
      [])
  end

  def work(%__MODULE__{} = x, d_val), do: %{x | done: x.done + d_val}

  def string(%CurWin{}=x) do
    case {x.val, x.dur} do
      {0, 4} -> "○"
      {1, 4} -> "◔"
      {2, 4} -> "◑"
      {3, 4} -> "◕"
      {4, 4} -> "●"
           _ -> "?"
    end
  end

  def idle?(x), do: x.done == 0
end

defmodule Trend do
  @bloks ["▀", " ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    |> Enum.with_index(fn x, i -> {i, x} end)
    |> Map.new()

  def make(len) do
    CircBuf.make(len, {0, 8})
  end

  def add(trend, %CurWin{done: d, broke: b}) do
    CircBuf.add(trend, {min(d, 8), b})
  end

  def idle_too_long?(trend) do
    trend
    |> CircBuf.take(2)
    |> Enum.all?(fn {w, b} -> w + b == 0 end)
  end

  def worked_too_long?(trend) do
    trend
    |> CircBuf.take(5)
    |> Enum.all?(fn {w, _} -> w > 0 end)
  end

  def to_list(x) do
    CircBuf.to_list(x)
  end

  def string(x, n) do
    CircBuf.take(x, n)
    |> Enum.map(fn {w, b} -> @bloks[ if b > 0 do 0 else w + 1 end ] end)
    |> Enum.join("")
    |> String.reverse
  end

  def stats(trend) do
    trend
    |> to_list()
    |> Enum.reduce({0, 0}, fn {b, w}, {ba, wa} -> {ba + b, wa + w} end)
  end

  def id(past) do
    CircBuf.count_while(past, & &1 == 0)
  end
end

defmodule Hourglass do
  def make(opts \\ []) do
    duration = Keyword.get(opts, :duration, 4)
    trend_bufsize = Keyword.get(opts, :trend, 180)
    {Trend.make(trend_bufsize), CurWin.make(duration)}
  end

  def past({x, _}), do: x
  def now({_, x}), do: x

  def tick(model, mode) do
    model
    |> tick_up(mode)
  end

  def alerts({past, now}) do
    if Trend.idle_too_long?(past) && CurWin.idle?(now) do
      a = Alarm.make_now(:countdown, 15, "split your task")
      |> Alarm.id("idle")
      [a]
    else
      []
    end
  end

  def progress({past, now}, dv), do: {past, CurWin.work(now, dv)}

  def remove_plan(model), do: model

  defp tick_up({past, %CurWin{} = now}, mode) do
    {now_, carry} = CurWin.tick(now, mode)
    past_ = Enum.reduce(carry, past, fn a, b -> Trend.add(b, a) end)
    {past_, now_}
  end

  def string({past, now}, {width, _}) do
    past_ = Trend.string(past, width - 3)
    now_ = CurWin.string(now)
    "#{past_} #{now_}"
  end

  def render(x, size) do
    import IO.ANSI
    cursor(1, 1) <> clear_line() <> string(x, size)
    |> IO.write
  end
end

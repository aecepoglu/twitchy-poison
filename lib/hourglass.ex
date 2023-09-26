defmodule CurWin do
  defstruct [dur: 8,
             val: 0,
             done: 0,
             broke: 0,
            ]

  def make(duration) do
    %__MODULE__{dur: duration}
  end

  def fin?(%__MODULE__{val: v, dur: d}), do: v >= d
  def reset(%__MODULE__{}=x), do:
    %__MODULE__{x | val: 0, done: 0, broke: 0}

  def tick(curwin, mode, d_val \\ 1)
  def tick(%__MODULE__{val: v} = x, :work, d_val), do:
    %__MODULE__{x | val: v + d_val}
  def tick(%__MODULE__{broke: v} = x, :break, d_val), do:
    %__MODULE__{x | broke: v + d_val,
                    val: v + d_val}

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
  @bloks [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    |> Enum.with_index(fn x, i -> {i, x} end)
    |> Map.new()

  def make(len) do
    CircBuf.make(len, nil)
  end

  def add(trend, %CurWin{done: d, broke: b}) do
    CircBuf.add(trend, {min(d, 8), b})
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
    
    # TODO [{now.done, now.broke} | Trend.take(past, 10)] |> analyse
    cond do
      Trend.idle_too_long?(past) && CurWin.idle?(now) ->
        [Alarm.make("idle", label: "split your task")]
      Trend.worked_too_long?(past) && now.broke == 0 ->
        [Alarm.make("rest", label: "take a break")]
      true -> []
    end
  end

  def progress({past, now}, dv), do: {past, CurWin.work(now, dv)}

  def remove_plan(model), do: model

  defp tick_up({past, %CurWin{} = now}, mode) do
    x = CurWin.tick(now, mode)
    if CurWin.fin?(x) do
      {Trend.add(past, x), CurWin.reset(x)}
    else
      {past, x}
    end
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

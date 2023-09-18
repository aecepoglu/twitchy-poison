defmodule CurWin do
  defstruct dur: 8,
            val: 0,
            done: 0,
            broke: 0,
            mode: :work

  def id(%CurWin{mode: m, done: d}), do: {m, d}

  def make(duration) do
    %__MODULE__{dur: duration}
  end

  defp tick_(%__MODULE__{val: v, dur: k} = me, carry) when v >= k do
    tick_(%{me | val: v - k, done: 0}, [%{me | val: k} | carry])
  end
  defp tick_(%__MODULE__{val: v} = me, carry) do
    {%{me | val: v}, carry |> Enum.reverse}
  end

  def tick(%__MODULE__{} = x, d_val \\ 1) do
    {_, _} = tick_(%{x | val: x.val + d_val}, [])
  end

  def progress(%__MODULE__{} = x, d_val) do
    k =
      case x.mode do
        :work -> :done
        _     -> :broke
      end

    %{x | k => Map.fetch!(x, k) + d_val}
  end

  def switch(%__MODULE__{} = x, to) when to in [:work, :break] do
    %{x | mode: to}
  end
  def string(%CurWin{}=x) do
    case {x.mode, x.val, x.dur} do
      {:break, _, _} -> "◬"
      {_     , 0, 5} -> "○"
      {_     , 1, 5} -> "◔"
      {_     , 2, 5} -> "◑"
      {_     , 3, 5} -> "◕"
      {_     , 4, 5} -> "●"
                   _ -> "?"
    end
  end

  def idle?(x), do: x.val == 0
end

defmodule Trend do
  @bloks ["B", " ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"] |> Enum.with_index(fn x, i -> {i, x} end) |> Map.new()

  def make(len) do
    CircBuf.make(len, -1)
  end

  def add(trend, %CurWin{mode: :break}) do
    CircBuf.add(trend, -1)
  end
  def add(trend, %CurWin{done: x}) do
    CircBuf.add(trend, x)
  end

  def idle_too_long?(trend) do
    trend
    |> CircBuf.take(2)
    |> Enum.all?(fn x -> x == 0 end)
  end

  def worked_too_long?(trend) do
    trend
    |> CircBuf.take(5)
    |> Enum.all?(fn x -> x > 0 end)
  end

  def to_list(x) do
    CircBuf.take(x, x.size)
  end

  def string(x, n) do
    CircBuf.take(x, n)
    |> Enum.map(fn k -> @bloks[ min(max(k + 1, 0), 9) ] end)
    |> Enum.join("")
  end

  def id(past) do
    CircBuf.count_while(past, & &1 == 0)
  end
end

defmodule Hourglass do
  def make(opts \\ []) do
    duration = Keyword.get(opts, :duration, 5)
    trend_bufsize = Keyword.get(opts, :trend, 5)
    {Trend.make(trend_bufsize), CurWin.make(duration)}
  end

  def tick(model) do
    model
    |> tick_up
    #|> decr_upcoming
    #|> create_idle_notifications()
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

  def switch_mode({past, now}, mode) do
    {past, CurWin.switch(now, mode)}
  end

  def progress({past, now}, dv), do: {past, CurWin.progress(now, dv)}

  def remove_plan(model), do: model

  defp tick_up({past, %CurWin{} = x}) do
    {x_, carry} = CurWin.tick(x)
    past_ = Enum.reduce(carry, past, fn a, b -> Trend.add(b, a) end)
    {past_, x_}
  end

  #def add_alarm({past, now, future}, new), do: {past, now, [new | future]}
  #def list_alarms({_, _, alarms}) do
  #  alarms
  #  |> Enum.filter(&Alarm.is_active?/1)
  #end
  #defp decr_upcoming({past, win, alarms}) do
  #  alarms_ = Alarm.ticks(alarms)
  #  {past, win, alarms_}
  #end
  #defp create_idle_notifications({past, win, alarms}) do
  #
  #  {past, win}
  #end

    #future_ = Alarm.string(future)

  def string({past, now}) do
    past_ = Trend.string(past, 5)
    now_ = CurWin.string(now)
    "#{past_} #{now_}"
  end

  def render(x) do
    import IO.ANSI
    cursor(1, 1) <> clear_line() <> string(x)
    |> IO.write
  end
end

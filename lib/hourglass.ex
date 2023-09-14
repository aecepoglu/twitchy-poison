
defmodule CurWin do
  defstruct dur: 8,
            val: 0,
            done: 0,
            broke: 0,
            mode: :work

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
        _ -> :broke
      end

    %{x | k => Map.fetch!(x, k) + d_val}
  end

  def switch(%__MODULE__{} = x, to) when to in [:work, :break] do
    %{x | mode: to}
  end
end

defmodule Alarm do
  defstruct [:type, :val, :snooze, :label]

  def make(:countdown, seconds_later, snooze, label) do
    %__MODULE__{type: :countdown, val: seconds_later, snooze: snooze, label: label}
  end

  def make_now(:countdown, snooze, label) do
    make(:countdown, 0, snooze, label)
  end

  def tick(%__MODULE__{type: :countdown} = x, dt \\ 1) do
    %{x | val: x.val - dt}
  end

  def ticks(list, dt) do
    Enum.map(list, &tick(&1, dt))
  end

  def is_active?(%{type: :countdown, val: v}), do: v <= 0
end

defmodule Trend do
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
end

defmodule Hourglass do
  def add_alarm({past, now, future}, new), do: {past, now, [new | future]}

  def make(opts \\ []) do
    duration = Keyword.get(opts, :duration, 5)
    trend_bufsize = Keyword.get(opts, :trend, 5)
    {Trend.make(trend_bufsize), CurWin.make(duration), []}
  end

  def tick(model) do
    model
    |> tick_up
    |> decr_upcoming
    |> create_idle_notifications()
  end

  def switch_mode({past, now, future}, mode) do
    {past, CurWin.switch(now, mode) , future}
  end

  def progress({past, now, future}, dv), do: {past, CurWin.progress(now, dv), future}

  def list_alarms({_, _, alarms}) do
    alarms
    |> Enum.filter(&Alarm.is_active?/1)
  end

  def remove_plan(model), do: model

  defp tick_up({past, %CurWin{} = x, alarms}) do
    {x_, carry} = CurWin.tick(x)
    past_ = Enum.reduce(carry, past, fn a, b -> Trend.add(b, a) end)

    {past_, x_, alarms}
  end

  defp decr_upcoming({past, win, alarms}) do
    alarms_ = Enum.map(alarms, &Alarm.tick/1)
    {past, win, alarms_}
  end

  defp create_idle_notifications({past, win, alarms}) do
    alarms_ =
      if Trend.idle_too_long?(past) do
        [Alarm.make_now(:countdown, 0, "split your task") | alarms]
      else
        alarms
      end

    {past, win, alarms_}
  end

  def to_string({past,%CurWin{}=now,_future}) do
    past_ = past
    |>Trend.to_list
    |> Enum.map(fn x -> if x < 0 do "-" else Integer.to_string(x) end end)
    |> Enum.join
    now_ = "#{now.val}/#{now.dur}#{if now.mode == :work do 'w' else 'b' end}"
    future_ = "-"
    "#{past_} #{now_} #{future_}"
  end
end

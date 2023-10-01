defmodule Progress.Hourglass do
  alias Progress.Trend, as: Trend
  alias Progress.CurWin, as: CurWin

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

  def rewind({past, now}, k) do
    {Trend.rewind(past, k), now}
  end

  defp tick_up({past, %CurWin{} = now}, mode) do
    now_ = CurWin.tick(now, mode)
    if CurWin.fin?(now_) do
      {Trend.add(past, now_), CurWin.reset(now)}
    else
      {past, now_}
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

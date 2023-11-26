defmodule Progress.Hourglass do
  alias Progress.Trend, as: Trend
  alias Progress.CurWin, as: CurWin

  def make() do
    {Trend.make(), CurWin.make()}
  end

  def past({x, _}), do: x
  def now({_, x}), do: x
  def duration({past, _}), do: Trend.duration(past) + 1

  def tick({past, now}, mode) do
    item = case mode do
      :break   -> :break
      :meeting -> {:work, :small}
      _ ->        {:work, now}
    end
    {Trend.add(past, item), CurWin.make()}
  end

  def progress({past, now}, dv), do: {past, CurWin.work(now, dv)}

  def remove_plan(model), do: model

  def rewind({past, now}) do
    {Trend.rewind(past), now}
  end

  def string({past, now}, mode, {width, _}) do
    past_ = Trend.string(past, width - 4)
    now_ = CurWin.string(now)
    "#{past_} #{string_of_mode(mode)} #{now_}"
  end

  def string_of_mode(:break), do: "⏸"
  def string_of_mode(m) when m in [:work, :meeting, :chat], do: "⏵"
  def string_of_mode(_), do: "?"

  def render(x, mode, {width, height}) do
    import IO.ANSI
    cursor(1, 1) <> clear_line() <> string(x, mode, {width, height})
  end

  def idle?({past, now}) do
    CurWin.idle?(now) && Trend.idle(past) == 30
  end
end

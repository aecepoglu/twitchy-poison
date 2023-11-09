defmodule FlowState do
  @factor 3

  def ready_for?(%Popup{id: :rest}, %Model{}=m) do
    %{break: _, idle: i, work: w} = m.hg |> Progress.Hourglass.past |> Progress.Trend.recent_stats
    i * 9 <= w
  end
  def ready_for?(_, _), do: true

  def alarms(%Model{}=m) do
    if Progress.Hourglass.idle?(m.hg) do
      [Popup.Known.idle()]
    else
      []
    end
  end

  def suggest(%Model{}=m) do
    %{break: b, idle: i, work: w} = m.hg |> Progress.Hourglass.past |> Progress.Trend.stats
    (w + i) / @factor - b |> floor |> max(0)
  end

  def suggest_next_break(%Model{}=m) do
    %{break: b, idle: i, work: w} = m.hg |> Progress.Hourglass.past |> Progress.Trend.recent_stats()
    b * @factor - (i + w)
  end

  def recontextualise(%Popup{id: :rest}=popup, %Model{}=model) do #TODO details leaking
    Popup.label(popup, "take a #{suggest(model)}'-long break!")
  end
  def recontextualise(%Popup{}=popup, _), do: popup
end

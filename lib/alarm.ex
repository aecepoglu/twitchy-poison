defmodule Upcoming do
  def empty(), do: []

  def popup(alarms) do
    {fin, unfin} = Enum.split_with(alarms, fn {t, _} -> t <= 0 end)
    fin_ = Enum.map(fin, &elem(&1, 1))
    {unfin, fin_}
  end

  def add(alarms, %Popup{id: id, snooze: t}=popup) do
    if t <= 0 || has?(alarms, id) do
      []
    else
      [{t, popup}]
    end ++ alarms
  end

  def tick(alarms) do
    Enum.map(alarms, fn {t, x} -> {t - 1, x} end)
  end

  def has?(alarms, id) do
    alarms
    |> Enum.map(&elem(&1, 1))
    |> Popup.has_id?(id)
  end

  def render([{_, alarm} | _], {width, _}) do
    alarm.label
    |> String.split_at(width)
    |> elem(0)
  end
  def render([], _), do: "-"

  def ids(alarms) do
    alarms
    |> Enum.map(& &1 |> elem(1) |> Map.fetch!(:id))
    |> MapSet.new
  end
end

defmodule Popup.Actions do
  def rotate(model, _) do
    popups = case model.popups do
      [h | t] -> t ++ [h]
      x       -> x
    end
    %{model | popups: popups}
  end

  def delete(model, _) do
    %{model | popups:  case model.popups do
      [_|tl] -> tl
      x      -> x
    end}
  end

  def snooze(model, popup) do
    Map.update!(model, :upcoming, &Upcoming.add(&1, popup))
  end
end

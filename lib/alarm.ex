defmodule Upcoming do
  def empty(), do: []

  def popup(alarms, pred) do
    {fin, unfin} = Enum.split_with(alarms, fn {t, x} -> t <= 0 && pred.(x) end)
    fin_ = Enum.map(fin, fn {_, x} -> x end)
    {unfin, fin_}
  end

  def add(alarms, %Popup{snooze: 0}), do: alarms
  def add(alarms, %Popup{snooze: t}=popup) do
    add(alarms, popup, t)
  end
  def add(alarms, %Popup{id: id}=popup, delay) do
    if has?(alarms, id) do
      alarms
    else
      [{delay, popup} | alarms]
    end
  end

  def remove(alarms, id) do
    Enum.filter(alarms, fn {_, x} -> x.id != id end)
  end

  def tick(alarms) do
    Enum.map(alarms, fn {t, x} -> {t - 1, x} end)
  end

  def has?(alarms, id) do
    alarms
    |> Enum.map(&elem(&1, 1))
    |> Popup.List.has_id?(id)
  end

  def render([{t, alarm} | _], {width, _}) do
    "#{alarm.label} in #{t}'"
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

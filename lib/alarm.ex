defmodule Alarm do
  defstruct [:type, :val, :snooze, :label, :id]

  def make(:countdown, seconds_later, snooze, label) do
    %__MODULE__{type: :countdown, val: seconds_later, snooze: snooze, label: label}
  end

  def make_now(:countdown, snooze, label) do
    %__MODULE__{
      type: :countdown,
      val: 0,
      snooze: snooze,
      label: label,
    }
  end

  def add(list, %Alarm{id: nil}=new), do: add_(list, new)
  def add(list, new) do
    if Enum.any?(list, & &1.id == new.id) do
      list
    else
      add_(list, new)
    end
  end
  defp add_([%Alarm{val: v1}=h | t], %Alarm{val: v2}=new) when v2 < v1 do
    [new, h | t]
  end
  defp add_([h | t], new), do: [h | add(t, new)]
  defp add_([], new), do: [new]

  def tick(%__MODULE__{type: :countdown} = x, dt \\ 1) do
    %{x | val: x.val - dt}
  end

  def ticks(list, dt) do
    Enum.map(list, &tick(&1, dt))
  end

  def list_active(list) do
    Enum.filter(list, &is_active?/1)
  end

  def is_active?(%{type: :countdown, val: v}), do: v <= 0

  def string([]), do: "-"
  def string([h | _]), do: h.label
end

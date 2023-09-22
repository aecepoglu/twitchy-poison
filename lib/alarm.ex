
defmodule Alarm do
  defstruct [:type, :val, :snooze, :label, :id]

  def make(:countdown, seconds_later, snooze, label) do
    %__MODULE__{type: :countdown, val: seconds_later, snooze: snooze, label: label}
  end

  def id(%Alarm{}=a, val), do: %{a | id: val}

  def make_now(:countdown, snooze, label) do
    %__MODULE__{
      type: :countdown,
      val: 0,
      snooze: snooze,
      label: label,
    }
  end

  def delete(list, %Alarm{}=elem), do: Enum.filter(list, & &1 != elem)
  def delete(list, id), do: Enum.filter(list, & &1.id == id)

  def add(list, new) when new.id == nil, do: add_(list, new)
  def add(list, new) do
    case Enum.split_with(list, & &1.id == new.id) do
      {[h|_], _} when h.val >= new.val -> list
      {_    , rest}                    -> add_(rest, new)
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

  def popup([h | _]=ht) do
   alias Alarm.Actions, as: Actions
    popup = if is_active?(h) do
     actions = [
       {"snooze", [&Actions.unset_popup/1, &Actions.snooze/1, &Model.set_popup/1]},
       {"delete", [&Actions.unset_popup/1, Actions.delete(h)]},
       {"close", [&Actions.unset_popup/1]},
     ]
      Popup.make(h, actions: actions)
    else
      nil
    end
    {ht, popup}
  end
  def popup(x), do: {x, nil}

  def snooze(%Alarm{}=x), do: %{x | val: x.snooze}
  def snooze([h | t]), do: add(t, snooze(h))

  def render_tmp(list, _size), do:
    list
    |> Enum.map(& "#{&1.id}:#{&1.label}(#{&1.val}+#{&1.snooze})")
    |> Enum.join(", ")
    |> IO.puts
end

defmodule Alarm.Actions do
  # these will turn out to belong elsewhere, better
  def unset_popup(%Model{}=m), do: %{m | popup: nil}
  def snooze(%Model{}=m), do: %{m | alarms: Alarm.snooze(m.alarms)}
  def delete(%Alarm{}=elem) do
    fn %Model{}=m ->
      %{m | alarms: Alarm.delete(m.alarms, elem)}
    end
  end
end

defmodule ModelTest do
  use ExUnit.Case

  defp get_break_for(activity) do
    {:ok, _} = Chore.start_link(nil)
    # Chore.add(%Chore{label: "clean the dishes"})

    trend = activity
    |> Enum.map(fn {a, b} ->  %CurWin{done: a, broke: b} end)
    |> Enum.reduce(Trend.make(3), & Trend.add(&2, &1))

    Model.make()
    |> Map.update!(:hg, fn {_, now} -> {trend, now} end)
    |> Model.update(:start_break)
    |> Map.fetch!(:tmp)
  end

  test "countdowns create a popup when they're ready" do
    m = %{Model.make() | alarms: [Alarm.make_now(:countdown, 10, "an alarm")]}
    |> Model.update(:tick_minute)
    assert match?(%Popup{ label: "an alarm", actions: [_,_,_] }, m.popup)
  end

  test "action_1 on its Popup snoozes an Alarm, resetting the popup" do
    a = Alarm.make_now(:countdown, 10, "an alarm")
    b = Alarm.make_now(:countdown, 7, "the second alarm")
    m = %{Model.make() | alarms: [a, b]}
    |> Model.update(:tick_minute)
    |> Model.update(:action_1)

    assert match?(%Popup{ label: "the second alarm", actions: _}, m.popup)
    left = [Alarm.tick(b), Alarm.snooze(a)]
    assert left == m.alarms
  end

  test "get suggested at least 60 seconds" do
    %Break{t: time} = get_break_for([{0, 1}, {0, 4}, {0, 8}, {0, 1}])
    assert time == 60
  end

  test "get suggested the ideal break length" do
    %Break{t: time} = get_break_for([{5, 1}, {8, 4}, {7, 0}, {8, 1}])
    assert time == 120
  end
end

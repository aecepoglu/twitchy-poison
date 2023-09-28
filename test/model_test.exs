defmodule ModelTest do
  use ExUnit.Case

#  defp log_activity(%Trend{}=trend, activity) do
#    trend = activity
#    |> Enum.map(fn {a, b} ->  %CurWin{done: a, broke: b} end)
#    |> Enum.reduce(trend, & Trend.add(&2, &1))
#  end
#
#  defp log_activity(model, activity) do
#    trend = log_activity(Trend.make(3), activity)
#    model
#    |> Map.update!(:hg, fn {_, now} -> {trend, now} end)
#  end
#
#  defp get_break_for(activity) do
#    Model.make()
#    |> log_activity(activity)
#    |> Model.update(:start_break)
#    |> Map.fetch!(:tmp)
#  end

  test "countdowns create a popup when they're ready" do
    m = %{Model.make() | alarms: [Alarm.make(nil, label: "an alarm")]}
        |> Model.update(:tick_minute)
    assert match?(%Popup{ label: "an alarm", actions: [_,_,_] },
                  m.popup)
  end

  test "action_1 on its Popup snoozes an Alarm, resetting the popup" do
    a = Alarm.make(nil, snooze: 10, label: "an alarm")
    b = Alarm.make(nil, snooze: 7, label: "the second alarm")
    m = %{Model.make() | alarms: [a, b]}
        |> Model.update(:tick_minute)
        |> Model.update(:action_1)

    assert match?(%Popup{ label: "the second alarm", actions: _},
                  m.popup)
    assert m.alarms == [Alarm.tick(b), Alarm.snooze(a)]
  end

#  @tag :skip
#  test "get suggested at least 60 seconds" do
#    {:ok, _} = Chore.start_link(nil)
#    %Break{t: time} = get_break_for([{0, 1}, {0, 4}, {0, 8}, {0, 1}])
#    assert time == 60
#  end
#
#  @tag :skip
#  test "get suggested the ideal break length" do
#    {:ok, _} = Chore.start_link(nil)
#    %Break{t: time} = get_break_for([{5, 1}, {8, 4}, {7, 0}, {8, 1}])
#    assert time == 120
#  end
#
#  @tag :skip
#  test "working for too long without a break is a cause for a break-reminder" do
#    alarms = Hourglass.make()
#    |> log_activity(1..10 |> Enum.map(fn _ -> {1, 0} end))
#    |> Model.update(:tick_minute)
#    |> Map.fetch!(:alarms)
#
#    assert alarms == [%Alarm{}] # an alarm for a break-reminder
#  end
end

defmodule ModelTest do
  use ExUnit.Case

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
end

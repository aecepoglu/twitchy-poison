defmodule ModelTest do
  use ExUnit.Case

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

  test "get suggested at least 60 seconds" do
    assert true
  end

  test "get suggested the ideal break length" do
    assert true
  end

end

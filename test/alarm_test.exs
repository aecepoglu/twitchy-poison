defmodule AlarmTest do
  use ExUnit.Case

  test "tick(dt)" do
    alarm =
      Alarm.make(nil, later: 120, snooze: 600, label: "two mins passed")
      |> Alarm.tick(17)

    assert alarm == Alarm.make(nil, later: 103, snooze: 600, label: "two mins passed")
  end

  test "list_active() lists nothing" do
    alarms =
      [Alarm.make(nil, later: 1)]
      |> Alarm.list_active
    assert alarms == []
  end

  test "list_active() lists active ones" do
    alarms =
      [Alarm.make(nil, later: 1, label: "twenty seconds")]
      |> Alarm.ticks(1)
      |> Alarm.list_active
    assert alarms == [Alarm.make(nil, later: 0, label: "twenty seconds")]
  end

  test "add() sorted" do
    existing = [x1, x2, x3] = [
      Alarm.make(nil, later: 7,  label: "old 1"),
      Alarm.make(nil, later: 17, label: "old 2"),
      Alarm.make(nil, later: 23, label: "old 3"),
    ]
    a = Alarm.make(nil, later: 20, label: "new 1")
    assert Alarm.add(existing, a) == [x1, x2, a, x3]
  end

  test "add() overwrites if the same exists" do
    old = [ %Alarm{id: "some id", later: 13, snooze: 17, label: "old label"} ]
    new = %Alarm{id: "some id", later: 20, snooze: 23, label: "new label"}
    assert Alarm.add(old, new) == [new]
  end
end

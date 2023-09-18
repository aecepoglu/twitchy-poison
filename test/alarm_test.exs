defmodule AlarmTest do
  use ExUnit.Case

  test "tick(dt)" do
    right =
      Alarm.make(:countdown, 120, 600, "two mins passed")
      |> Alarm.tick(17)

    assert Alarm.make(:countdown, 103, 600, "two mins passed") == right
  end

  test "list_active() lists nothing" do
    right =
      [Alarm.make(:countdown, 1, 100, "twenty seconds")]
      |> Alarm.list_active
    assert [] == right
  end

  test "list_active() lists active ones" do
    right =
      [Alarm.make(:countdown, 1, 100, "twenty seconds")]
      |> Alarm.ticks(1)
      |> Alarm.list_active
    assert [Alarm.make(:countdown, 0, 100, "twenty seconds")] == right
  end

  test "add() sorted" do
    existing = [x1, x2, x3] = [
      Alarm.make(:countdown, 7,  100, "existing"),
      Alarm.make(:countdown, 17, 100, "existing"),
      Alarm.make(:countdown, 23, 100, "existing"),
    ]
    a = Alarm.make(:countdown, 20, 100, "existing")
    assert Alarm.add(existing, a) == [x1, x2, a, x3]
  end

  test "add() overwrites if the same exists" do
    old = [ %Alarm{id: "some id", val: 13, snooze: 17, label: "old label"} ]
    new = %Alarm{id: "some id", val: 20, snooze: 23, label: "new label"}
    right = Alarm.add(old, new)
    assert [new] == right
  end
end

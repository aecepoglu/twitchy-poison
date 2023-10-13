defmodule UpcomingTest do
  use ExUnit.Case

  test "tick(dt)" do
    p1 = Popup.make(:id1, "label 1", snooze: 5)
    p2 = Popup.make(:id2, "label 2", snooze: 6)
    {alarms, popups} =
      Upcoming.empty()
      |> Upcoming.add(p1)
      |> Upcoming.add(p2)
      |> Upcoming.tick()
      |> Upcoming.tick()
      |> Upcoming.tick()
      |> Upcoming.tick()
      |> Upcoming.tick()
      |> Upcoming.popup

    assert {alarms, popups} == {
      [{1, p2}],
      [p1]
    }
  end
end

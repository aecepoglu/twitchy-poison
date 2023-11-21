defmodule UpcomingTest do
  use ExUnit.Case

  test "popup from upcoming" do
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
      |> Upcoming.popup(fn _ -> true end)

    assert {alarms, popups} == {
      [{1, p2}],
      [p1]
    }
  end

  test "dont popup if the check fails, even if their time comes" do
    popup1 = Popup.make(:rest, "take a break", snooze: 5)
    popup2 = Popup.make(:xyz, "ex why zed")
    {unfin, fin} =
      Upcoming.empty()
      |> Upcoming.add(popup1, 3)
      |> Upcoming.add(popup2, 10)
      |> Upcoming.tick()
      |> Upcoming.tick()
      |> Upcoming.tick()
      |> Upcoming.popup(fn _ -> false end)

    assert {unfin, fin} ==
      { [{0, popup1}, {7, popup2}],
        [] }
  end

  test "render in same line" do
    popup1 = Popup.make(:rest, "take a break", snooze: 5)
    popup2 = Popup.make(:one, "ex why zed")
    popup3 = Popup.make(:two, "popup three")
    txt = Upcoming.empty()
    |> Upcoming.add(popup1, 10)
    |> Upcoming.add(popup2, 3)
    |> Upcoming.add(popup3, 5)
    |> Upcoming.render({100, 1})

    assert txt == "ex why zed in 3' // popup three in 5' // take a break in 10'"
  end

  test "render as many elements as fits" do
    popup1 = Popup.make(:rest, "take a break", snooze: 5)
    popup2 = Popup.make(:one, "ex why zed")
    popup3 = Popup.make(:two, "popup three")
    txt = Upcoming.empty()
    |> Upcoming.add(popup1, 10)
    |> Upcoming.add(popup2, 3)
    |> Upcoming.add(popup3, 5)
    |> Upcoming.render({45, 1})

    assert txt == "ex why zed in 3' // popup three in 5'"
  end
end
